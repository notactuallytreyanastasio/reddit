defmodule RedditWeb.LinkDetailLive do
  use RedditWeb, :live_view

  alias Reddit.Content
  alias Reddit.Content.Comment
  alias Reddit.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Use try/rescue to handle the case when the link is not found
    try do
      link = Content.get_link_with_comments!(id)

      if connected?(socket) do
        Phoenix.PubSub.subscribe(Reddit.PubSub, "comments:#{id}:new")
      end

      {:ok,
       socket
       |> assign(:page_title, link.title)
       |> assign(:link, link)
       |> assign(:comments, link.comments)
       |> assign(:comment_changeset, Content.change_comment(%Comment{}))
       |> assign(:username, "")
       |> assign(:parent_comment_id, nil)}
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(:error, "Link not found")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("save_comment", %{"comment" => comment_params, "username" => username}, socket) do
    # Find or create user based on username
    username_params = %{username: username}
    user_result = Accounts.find_or_create_user_by_username(username_params)

    case user_result do
      {:ok, user} ->
        # Add required fields to comment_params
        comment_attrs =
          Map.merge(comment_params, %{
            "user_id" => user.id,
            "link_id" => socket.assigns.link.id,
            "parent_comment_id" => socket.assigns.parent_comment_id,
            "posted_at" => DateTime.utc_now()
          })

        case Content.create_comment(comment_attrs) do
          {:ok, _comment} ->
            {:noreply,
             socket
             |> assign(:comment_changeset, Content.change_comment(%Comment{}))
             |> assign(:username, username)
             |> assign(:parent_comment_id, nil)}

          {:error, changeset} ->
            {:noreply, assign(socket, :comment_changeset, changeset)}
        end

      {:error, _reason} ->
        {:noreply, socket |> put_flash(:error, "Error with username. Please try again.")}
    end
  end

  @impl true
  def handle_event(
        "validate_comment",
        %{"comment" => comment_params, "username" => username},
        socket
      ) do
    changeset =
      %Comment{}
      |> Content.change_comment(comment_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:comment_changeset, changeset)
     |> assign(:username, username)}
  end

  @impl true
  def handle_event("reply_to_comment", %{"id" => parent_id}, socket) do
    {:noreply, assign(socket, :parent_comment_id, parent_id)}
  end

  @impl true
  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, :parent_comment_id, nil)}
  end

  @impl true
  def handle_info(%{event: "new_comment", payload: comment_payload}, socket) do
    updated_comments = socket.assigns.comments ++ [comment_payload]
    {:noreply, assign(socket, :comments, updated_comments)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-3 py-4">
      <!-- Link detail section -->
      <div class="mb-6">
        <div class="flex items-center mb-3">
          <a
            href={~p"/"}
            class="px-3 py-1.5 rounded-full hover:scale-105 transition-transform mr-2"
            style="background: linear-gradient(to right, var(--color-baby-blue), var(--color-bright-blue)); color: white; font-family: var(--font-heading); font-weight: 600; box-shadow: 0 3px 10px rgba(137,207,240,0.3); font-size: 0.9rem;"
          >
            Back to All
          </a>
          <span style="font-family: var(--font-text); color: var(--color-bright-purple);">
            in
            <a
              href={~p"/topics/#{@link.topic.slug}"}
              style="font-weight: 600; background: linear-gradient(to right, var(--color-hot-pink), var(--color-bright-purple)); -webkit-background-clip: text; -webkit-text-fill-color: transparent;"
            >
              {@link.topic.name}
            </a>
          </span>
        </div>

        <div style="border-radius: 12px; background-color: white; padding: 20px; box-shadow: 0 3px 15px rgba(137,207,240,0.15); border: 1px solid rgba(255,105,180,0.2);">
          <!-- Link title with colorful styling -->
          <div class="mb-3">
            <h1 style="font-family: var(--font-display); font-size: 2rem; color: var(--color-bright-pink); margin-bottom: 0.5rem">
              {@link.title}
            </h1>
          </div>
          
    <!-- URL with happy styling -->
          <div class="mb-4" style="font-family: var(--font-text);">
            <a
              href={@link.url}
              target="_blank"
              style="color: var(--color-bright-blue); font-weight: 600; text-decoration: underline; text-decoration-color: rgba(137,207,240,0.5); text-underline-offset: 2px;"
              class="hover:text-[#1E90FF]"
            >
              {@link.url}
            </a>
          </div>
          
    <!-- Link body with bright styling -->
          <%= if @link.body do %>
            <div style="border-radius: 10px; border: 2px solid rgba(255,105,180,0.2); padding: 15px; margin-top: 12px; background-color: rgba(255,240,252,0.5);">
              <div style="font-family: var(--font-text); color: var(--color-text); white-space: pre-wrap; overflow-x: auto; line-height: 1.5;">
                {@link.body}
              </div>
            </div>
          <% end %>
          
    <!-- Link metadata with colorful styling -->
          <div class="mt-4" style="font-family: var(--font-text); font-size: 0.9rem;">
            <div class="flex justify-between items-center">
              <span style="color: var(--color-teal);">
                Posted by <span style="font-weight: 600;">{@link.user.username}</span>
              </span>
              <span style="color: var(--color-neon-orange);">{relative_time(@link.posted_at)}</span>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Comments section -->
      <div class="mb-6">
        <h2 style="font-family: var(--font-display); font-size: 1.8rem; background: linear-gradient(to right, var(--color-bright-purple), var(--color-bright-blue)); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 1rem">
          Comments
        </h2>
        
    <!-- Comment form with colorful styling -->
        <div style="border-radius: 12px; background-color: white; padding: 20px; margin-bottom: 20px; box-shadow: 0 3px 15px rgba(137,207,240,0.15); border: 1px solid rgba(191,95,255,0.2);">
          <h3 style="font-family: var(--font-heading); color: var(--color-bright-purple); margin-bottom: 12px; font-weight: 600; font-size: 1.2rem;">
            <%= if @parent_comment_id do %>
              Replying to a comment
              <button
                phx-click="cancel_reply"
                class="ml-2 px-3 py-1 rounded-full text-xs"
                style="background-color: rgba(255,105,180,0.1); color: var(--color-hot-pink); font-weight: 600;"
              >
                Cancel
              </button>
            <% else %>
              Add your comment
            <% end %>
          </h3>

          <.form for={@comment_changeset} phx-submit="save_comment" phx-change="validate_comment">
            <div class="mb-4">
              <.input
                field={@comment_changeset[:body]}
                type="textarea"
                label="Your comment"
                required
                style="font-family: var(--font-text); color: var(--color-text); background-color: white; border: 2px solid rgba(191,95,255,0.3); border-radius: 8px; resize: vertical; min-height: 100px;"
              />
            </div>

            <div class="mb-4">
              <.input
                name="username"
                value={@username}
                placeholder="Your display name"
                label="Username"
                required
                style="font-family: var(--font-text); color: var(--color-text); background-color: white; border: 2px solid rgba(255,105,180,0.3); border-radius: 8px;"
              />
            </div>

            <.button
              type="submit"
              class="px-4 py-2 rounded-full hover:scale-105 transition-transform"
              style="background: linear-gradient(to right, var(--color-hot-pink), var(--color-bright-pink)); color: white; font-family: var(--font-heading); font-weight: 600; box-shadow: 0 3px 10px rgba(255,105,180,0.3);"
            >
              Post Comment ✨
            </.button>
          </.form>
        </div>
        
    <!-- Comments list with colorful styling -->
        <div class="comments-container space-y-4">
          <%= if Enum.empty?(@comments) do %>
            <div
              class="flex justify-center items-center py-6"
              style="border: 2px dashed var(--color-hot-pink); border-radius: 12px; background-color: rgba(255,105,180,0.05);"
            >
              <p style="font-family: var(--font-text); color: var(--color-hot-pink); font-size: 1.1rem;">
                No comments yet. Be the first to share your thoughts! ✨
              </p>
            </div>
          <% else %>
            <%= for comment <- @comments do %>
              <div
                id={"comment-#{comment.id}"}
                style="border-radius: 12px; background-color: white; padding: 15px; box-shadow: 0 3px 12px rgba(137,207,240,0.15); border: 1px solid rgba(255,105,180,0.2);"
              >
                <div class="flex flex-col">
                  <div
                    class="flex justify-between"
                    style="font-family: var(--font-text); margin-bottom: 6px;"
                  >
                    <span style="color: var(--color-bright-purple); font-weight: 600;">
                      {comment.user.username}
                    </span>
                    <span style="color: var(--color-neon-orange); font-size: 0.9rem;">
                      {relative_time(comment.posted_at)}
                    </span>
                  </div>

                  <div style="font-family: var(--font-text); color: var(--color-text); padding: 8px; background-color: rgba(255,240,252,0.5); border-radius: 8px; margin: 4px 0 10px; line-height: 1.4;">
                    {comment.body}
                  </div>

                  <div class="text-right">
                    <button
                      phx-click="reply_to_comment"
                      phx-value-id={comment.id}
                      class="px-3 py-1 rounded-full hover:scale-105 transition-transform text-sm"
                      style="background: linear-gradient(to right, var(--color-baby-blue), var(--color-bright-blue)); color: white; font-family: var(--font-heading); font-weight: 600; box-shadow: 0 2px 8px rgba(137,207,240,0.3);"
                    >
                      Reply
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      
    <!-- Footer stats -->
      <div
        class="text-center mt-5 py-2"
        style="font-family: var(--font-text); background: linear-gradient(to right, rgba(255,105,180,0.05), rgba(137,207,240,0.05), rgba(255,105,180,0.05)); border-radius: 20px;"
      >
        <span style="color: var(--color-bright-purple); font-weight: 600;">
          {Enum.count(@comments)} Comments
        </span>
        💬
        <a
          href={~p"/topics/#{@link.topic.slug}"}
          style="color: var(--color-hot-pink); border-bottom: 2px dotted var(--color-hot-pink); font-weight: 600; padding-bottom: 1px;"
        >
          Back to {@link.topic.name}
        </a>
      </div>
    </div>
    """
  end

  # Helper to format relative time
  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2_592_000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2_592_000)}mo ago"
    end
  end
end
