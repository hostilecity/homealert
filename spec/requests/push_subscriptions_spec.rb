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

        it "returns the record id and endpoint digest" do
          post push_subscriptions_path, params: valid_params
          json = JSON.parse(response.body)
          expect(json["id"]).to eq(PushSubscription.last.id)
          expect(json["endpoint_digest"]).to eq(PushSubscription.last.endpoint_digest)
        end
      end

      context "with several devices" do
        it "keeps a subscription per device" do
          first  = valid_params
          second = valid_params.deep_merge(
            subscription: {
              endpoint:     "https://web.push.apple.com/unique-token-xyz",
              device_label: "Safari on iPhone"
            }
          )

          expect {
            post push_subscriptions_path, params: first
            post push_subscriptions_path, params: second
          }.to change { user.push_subscriptions.count }.by(2)

          expect(user.push_subscriptions.pluck(:device_label))
            .to contain_exactly("My Phone", "Safari on iPhone")
        end
      end

      context "when the device reports a rotated endpoint" do
        let!(:stale) do
          create(:push_subscription, user: user, endpoint: "https://fcm.googleapis.com/fcm/send/old-token")
        end

        let(:rotated_params) do
          valid_params.deep_merge(
            subscription: { previous_endpoint: "https://fcm.googleapis.com/fcm/send/old-token" }
          )
        end

        it "removes the superseded record" do
          post push_subscriptions_path, params: rotated_params
          expect(PushSubscription.exists?(stale.id)).to be(false)
        end

        it "keeps the newly reported subscription" do
          post push_subscriptions_path, params: rotated_params
          expect(user.push_subscriptions.pluck(:endpoint))
            .to eq([ valid_params[:subscription][:endpoint] ])
        end

        it "does not remove another user's record with that endpoint" do
          stale.update!(user: create(:user))
          post push_subscriptions_path, params: rotated_params
          expect(PushSubscription.exists?(stale.id)).to be(true)
        end

        it "does not remove the record it just saved when the endpoint is unchanged" do
          params = valid_params.deep_merge(
            subscription: { previous_endpoint: valid_params[:subscription][:endpoint] }
          )
          post push_subscriptions_path, params: params
          expect(user.push_subscriptions.where(endpoint: valid_params[:subscription][:endpoint])).to exist
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

        it "leaves the user's other devices subscribed" do
          other_device = create(:push_subscription, user: user)
          delete push_subscription_path(subscription)
          expect(user.push_subscriptions.reload).to contain_exactly(other_device)
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
