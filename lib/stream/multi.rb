class Stream::Multi < Stream::Base

  # @return [String] URL
  def link(opts)
    Rails.application.routes.url_helpers.multi_path
  end

  # @return [String]
  def title
    I18n.t('streams.multi.title')
  end

  # @return [String]
  def contacts_title
    I18n.t('streams.multi.contacts_title')
  end

  def posts
    @posts ||= lambda do
      post_ids = aspects_post_ids + followed_tags_post_ids + mentioned_post_ids
      post_ids += community_spotlight_post_ids if include_community_spotlight?
      Post.where(:id => post_ids).for_a_stream(max_time, order)
    end.call
  end

  # @return [Boolean]
  def ajax_stream?
    false
  end

  #emits an enum of the groups which the post appeared
  # :spotlight, :aspects, :tags, :mentioned
  def post_from_group(post)
    streams_included.collect do |source| 
      is_in?(source, post)
    end.compact
  end

  private

  # @return [Array<Symbol>]
  def streams_included
    @streams_included ||= lambda do
      array = [:mentioned, :aspects, :followed_tags]
      array << :community_spotlight if include_community_spotlight?
      array
    end.call
  end

  # @return [Symbol]
  def is_in?(sym, post)
    if self.send("#{sym.to_s}_post_ids").find{|x| x == post.id}
      "#{sym.to_s}_stream".to_sym
    end
  end

  # @return [Boolean]
  def include_community_spotlight?
    AppConfig[:community_spotlight].present? && user.show_community_spotlight_in_stream?
  end

  def aspects_post_ids
    @aspects_post_ids ||= user.visible_shareable_ids(Post, :limit => 15, :order => "#{order} DESC", :max_time => max_time, :all_aspects? => true, :by_members_of => aspect_ids)
  end

  def followed_tags_post_ids
    @followed_tags_ids ||= ids(StatusMessage.tag_stream(user, tag_array, max_time, order))
  end

  def mentioned_post_ids
    @mentioned_post_ids ||= ids(StatusMessage.where_person_is_mentioned(user.person).for_a_stream(max_time, order))
  end

  def community_spotlight_post_ids
    @community_spotlight_post_ids ||= ids(Post.all_public.where(:author_id => community_spotlight_person_ids).for_a_stream(max_time, order))
  end

  #worthless helpers
  def community_spotlight_person_ids
    @community_spotlight_person_ids ||= Person.community_spotlight.select('id').map{|x| x.id}
  end

  def tag_array
    user.followed_tags.select('name').map{|x| x.name}
  end

  def ids(enumerable)
    Post.connection.select_values(enumerable.select('posts.id').to_sql)
  end
end
