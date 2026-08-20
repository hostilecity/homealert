require "rails_helper"

RSpec.describe "PushSubscriptions", type: :request do
  let(:user) { create(:user) }

  let(:valid_params) do
    {
      subscription: {
        endpoint:     "https://fcm.googleapis.com/fcm/send/unique-token-abc",
        p256dh_key:   "p256dh_key_value",
        auth_key:     "auth_key_value",
        device_label: "My Phone"
      }
    }
  end

  # ------------------------------------------------------------------ #
  # POST /push_subscriptions                                             #
  # ------------------------------------------------------------------ #
  describe "POST /push_subscriptions" do
    context "when not signed in" do
      it "redirects to login" do
        post push_subscriptions_path, params: valid_params
        expect(response).to redirect_to(login_path)
      end
    end

    context "when signed in" do
      before { sign_in(user) }

      context "with a valid HTTPS endpoint" do
        it "creates a push subscription" do
          expect {
            post push_subscriptions_path, params: valid_params
          }.to change(PushSubscription, :count).by(1)
        end

        it "returns 201 Created" do
          post push_subscriptions_path, params: valid_params
          expect(response).to have_http_status(:created)
        end
      end

      context "with a private/local IP endpoint" do
        it "returns 422 for 192.168.x.x" do
          params = valid_params.deep_merge(subscription: { endpoint: "https://192.168.1.1/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns 422 for 10.x.x.x" do
          params = valid_params.deep_merge(subscription: { endpoint: "https://10.0.0.1/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns 422 for 172.16.x.x" do
          params = valid_params.deep_merge(subscription: { endpoint: "https://172.16.0.1/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "with a localhost endpoint" do
        it "returns 422 for http://localhost" do
          params = valid_params.deep_merge(subscription: { endpoint: "http://localhost/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns 422 for https://localhost" do
          params = valid_params.deep_merge(subscription: { endpoint: "https://localhost/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns 422 for 127.0.0.1" do
          params = valid_params.deep_merge(subscription: { endpoint: "https://127.0.0.1/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "with a plain HTTP endpoint" do
        it "returns 422" do
          params = valid_params.deep_merge(subscription: { endpoint: "http://fcm.googleapis.com/push" })
          post push_subscriptions_path, params: params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "with missing subscription params" do
        it "returns 422" do
          post push_subscriptions_path, params: {}
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "when the endpoint already exists (find_or_update)" do
        let!(:existing) do
          create(:push_subscription,
                 user:     user,
                 endpoint: valid_params[:subscription][:endpoint])
        end

        it "does not create a duplicate" do
          expect {
            post push_subscriptions_path, params: valid_params
          }.not_to change(PushSubscription, :count)
        end

        it "updates the existing subscription and returns 201" do
          updated_params = valid_params.deep_merge(
            subscription: { device_label: "Updated Label" }
          )
          post push_subscriptions_path, params: updated_params
          expect(response).to have_http_status(:created)
          expect(existing.reload.device_label).to eq("Updated Label")
        end
      end
    end
  end

  # ------------------------------------------------------------------ #
  # DELETE /push_subscriptions/:id                                       #
  # ------------------------------------------------------------------ #
  describe "DELETE /push_subscriptions/:id" do
    context "when not signed in" do
      it "redirects to login" do
        delete push_subscription_path(1)
        expect(response).to redirect_to(login_path)
      end
    end

    context "when signed in" do
      before { sign_in(user) }

      context "when the subscription belongs to the current user" do
        let!(:subscription) { create(:push_subscription, user: user) }

        it "destroys the subscription" do
          expect {
            delete push_subscription_path(subscription)
          }.to change(PushSubscription, :count).by(-1)
        end

        it "returns 204 No Content" do
          delete push_subscription_path(subscription)
          expect(response).to have_http_status(:no_content)
        end
      end

      context "when the subscription does not belong to the current user" do
        let(:other_user)  { create(:user) }
        let!(:other_sub)  { create(:push_subscription, user: other_user) }

        it "returns 404 Not Found" do
          delete push_subscription_path(other_sub)
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when the subscription id does not exist" do
        it "returns 404 Not Found" do
          delete push_subscription_path(id: 999_999)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
