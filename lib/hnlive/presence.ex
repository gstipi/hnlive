defmodule HNLive.Presence do
  use Phoenix.Presence,
    otp_app: :hnlive,
    pubsub_server: HNLive.PubSub
end
