miquire :core, 'plugin'
require 'net/http'
require 'uri'
require 'nokogiri'

Plugin.create(:shindanmaker) do
  Gtk::TimeLine.addopenway(/^http:\/\/shindanmaker.com\/[0-9]+/) { |shrinked_url, cancel|
    url = MessageConverters.expand_url_one(shrinked_url)
    name = Post.services.first.user
    Delayer.new(Delayer::NORMAL) {
      begin
        res = Net::HTTP.post_form(URI.parse(url), {'u' => name})
        doc = Nokogiri::HTML::parse(res.body)
        txt = doc.xpath('//textarea').first.inner_text
        Gtk::PostBox.list.first.widget_post.buffer.text = txt
      rescue
        notice "shindan failed: #{url}"
      end
    }
  }
end
