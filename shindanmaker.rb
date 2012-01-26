#-*- coding: utf-8

require 'net/http'
require 'uri'
require 'nokogiri'

Plugin.create(:shindanmaker) do
  UserConfig[:shindanmaker_timeout] ||= 10

  Gtk::TimeLine.addopenway(/^http:\/\/shindanmaker\.com\/[0-9]+/) { |shrinked_url, cancel|
    url = MessageConverters.expand_url_one(shrinked_url)
    notice url
    begin
      match = url.to_s.match(/^http:\/\/shindanmaker\.com\/([0-9]+)/)
      shindan_num = match[1]
    rescue
      Plugin.call(:rewindstatus, "診断URLが取得できませんでした")
      cancel.call
      break
    end
    name = Post.services.first.user

    Delayer.new(Delayer::NORMAL) {
      postboxes = Plugin.filtering(:main_postbox, nil).first
      postbox = Gtk::ServiceBox.new(Post.primary_service,
                                postboxstorage: postboxes)
      widget = postbox.widget_post
      postboxes.pack_start(postbox).show_all.get_ancestor(Gtk::Window).set_focus(widget)
      widget.buffer.text = "(診断中)"
      widget.sensitive = false
      Thread.new {
        begin
          Net::HTTP.start('shindanmaker.com') do |http|
            http.read_timeout = UserConfig[:shindanmaker_timeout].to_i
            res = http.post("/#{shindan_num}", "u=#{name}")
            doc = Nokogiri::HTML::parse(res.body)
            txt = doc.xpath('//textarea').first.inner_text
            widget.buffer.text = txt
            if postbox.respond_to? :refresh_buttons # 0.0.4以前でも動作するように
              postbox.refresh_buttons end
          end
        rescue
          notice "shindan failed: #{url}, #{$!}"
          Plugin.call(:rewindstatus, "診断がタイムアウトしました")
          widget.buffer.text = ""
        ensure
          widget.sensitive = true
        end
      }
    }
  }

  settings("診断メーカー") do
    adjustment("タイムアウト(sec)", :shindanmaker_timeout, 0, 60)
  end
end
