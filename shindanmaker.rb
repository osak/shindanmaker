#-*- coding: utf-8
miquire :core, 'plugin'
require 'net/http'
require 'uri'
require 'nokogiri'

Plugin.create(:shindanmaker) do
  UserConfig[:shindanmaker_timeout] ||= 10

  Gtk::TimeLine.addopenway(/^http:\/\/shindanmaker\.com\/[0-9]+/) { |shrinked_url, cancel|
    url = MessageConverters.expand_url_one(shrinked_url)
    match = url.match(/^http:\/\/shindanmaker\.com\/([0-9]+)/)
    if match.size < 2
      Plugin.call(:rewindstatus, "診断URLが取得できませんでした")
      return cancel
    end
    shindan_num = match[1]
    name = Post.services.first.user

    Delayer.new(Delayer::NORMAL) {
      widget = Gtk::PostBox.list.first.widget_post
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
