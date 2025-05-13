defmodule RedditWeb.TopicLinkListLive do
  use RedditWeb, :live_view

  alias Reddit.Content

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Reddit.PubSub, "links:new")
    end

    topic = Content.get_topic_by_slug(slug)

    if topic do
      {:ok,
       socket
       |> assign(:topic, topic)
       |> assign(:page_title, "#{topic.name} Links")
       |> assign(:links, Content.list_links_by_topic_slug(slug))}
    else
      # Handle the case when topic is not found
      {:ok,
       socket
       |> put_flash(:error, "Topic not found")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info(%{event: "new_link", payload: link_payload}, socket) do
    # Only add the link to our list if it belongs to the current topic
    if link_payload.topic.slug == socket.assigns.topic.slug do
      updated_links = [link_payload | socket.assigns.links]
      {:noreply, assign(socket, :links, updated_links)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-3 py-4">
      <div class="flex flex-col md:flex-row md:justify-between md:items-center mb-5">
        <div>
          <h1 style="font-family: var(--font-display); font-size: 2.2rem; background: linear-gradient(to right, var(--color-bright-purple), var(--color-hot-pink)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 0.2rem">
            {@topic.name}
          </h1>
          <p style="font-family: var(--font-text); color: var(--color-bright-blue); font-size: 0.95rem; max-width: 600px; margin-top: 0; line-height: 1.4;">
            {@topic.description}
          </p>
        </div>
        <div class="flex space-x-3 mt-3 md:mt-0">
          <a
            href={~p"/"}
            class="px-3 py-1.5 rounded-full hover:scale-105 transition-transform"
            style="background: linear-gradient(to right, var(--color-baby-blue), var(--color-bright-blue)); color: white; font-family: var(--font-heading); font-weight: 600; box-shadow: 0 3px 10px rgba(137,207,240,0.3); font-size: 0.9rem;"
          >
            All Links 🏠
          </a>
          <a
            href={~p"/links/new"}
            class="px-3 py-1.5 rounded-full hover:scale-105 transition-transform"
            style="background: linear-gradient(to right, var(--color-hot-pink), var(--color-bright-pink)); color: white; font-family: var(--font-heading); font-weight: 600; box-shadow: 0 3px 10px rgba(255,105,180,0.3); font-size: 0.9rem;"
          >
            New Link ✨
          </a>
        </div>
      </div>

      <div class="links-container">
        <%= if Enum.empty?(@links) do %>
          <div
            class="flex justify-center items-center py-6"
            style="border: 2px dashed var(--color-bright-purple); border-radius: 12px; background-color: rgba(191,95,255,0.05);"
          >
            <p style="font-family: var(--font-text); color: var(--color-bright-purple); font-size: 1.1rem;">
              No links in "{@topic.name}" yet. Be the first to add one! 🌈
            </p>
          </div>
        <% else %>
          <div
            class="grid grid-cols-1 gap-3"
            style="grid-template-columns: repeat(auto-fill, minmax(100%, 1fr));"
          >
            <%= for link <- @links do %>
              <div
                class="link-card"
                style="border-radius: 12px; margin-bottom: 2px; padding: 12px 16px; position: relative; background: white; box-shadow: 0 3px 12px rgba(137,207,240,0.15); border: 1px solid rgba(191,95,255,0.2);"
              >
                <div
                  class="flex items-center gap-2"
                  style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap;"
                >
                  <a
                    href={~p"/links/#{link.id}"}
                    style="font-family: var(--font-heading); font-size: 1.1rem; font-weight: 600; color: var(--color-bright-blue); max-width: 90%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: inline-block; transition: color 0.2s;"
                    class="hover:text-[#FF1493]"
                  >
                    {link.title}
                  </a>
                </div>

                <div
                  class="flex justify-between items-center mt-2"
                  style="font-family: var(--font-text); font-size: 0.85rem; flex-wrap: wrap;"
                >
                  <div style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--color-bright-purple);">
                    <a
                      href={link.url}
                      target="_blank"
                      style="color: var(--color-bright-purple); max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: inline-block; text-decoration: underline; text-decoration-color: rgba(191,95,255,0.3); text-underline-offset: 2px;"
                    >
                      {link.url |> URI.parse() |> Map.get(:host) |> to_string()}
                    </a>
                  </div>

                  <div style="color: var(--color-bright-pink); font-size: 0.8rem;">
                    <span style="color: var(--color-teal);">{link.user.username}</span>
                    •
                    <span style="color: var(--color-neon-orange);">
                      {relative_time(link.posted_at)}
                    </span>
                    •
                    <span style="color: var(--color-baby-blue);">{link.comment_count} comments</span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <div
        class="text-center mt-5 py-2"
        style="font-family: var(--font-text); background: linear-gradient(to right, rgba(191,95,255,0.05), rgba(255,105,180,0.05), rgba(191,95,255,0.05)); border-radius: 20px;"
      >
        <span style="font-weight: 600; background: linear-gradient(to right, var(--color-bright-purple), var(--color-hot-pink)); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
          Topic: {@topic.name} • {Enum.count(@links)} Links
        </span>
      </div>
    </div>
    """
  end

  # Helper to format relative time
  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      true -> "#{div(diff, 2_592_000)} months ago"
    end
  end
end
