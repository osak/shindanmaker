#-*- coding: utf-8

require 'net/http'
require 'uri'
require 'nokogiri'

Plugin.create(:shindanmaker) do
  UserConfig[:shindanmaker_timeout] ||= 10
  UserConfig[:shindanmaker_name] ||= Post.services.first.user
  @main_window = nil
  @shindan_num_of = {}

  Gtk::TimeLine.addopenway(/^http:\/\/shindanmaker\.com\/[0-9]+/) { |shrinked_url, cancel|
    url = MessageConverters.expand_url_one(shrinked_url)
    notice url
    begin
      match = url.to_s.match(/^http:\/\/shindanmaker\.com\/([0-9]+)/)
      shindan_num = match[1]
    rescue
      Plugin.activity(:error, "診断URLが処理できない形式です： #{url}")
      cancel.call
      next
    end

    # Postboxをトップレベルウィンドウに追加してから実体が取得可能になるには，Pluginの発火を待たないといけない．
    # よって診断番号だけ保存しておいて，Postboxが登録完了してから診断を開始するようにする．
    i_postbox = Plugin::GUI::Postbox.instance
    @main_window << i_postbox
    @shindan_num_of[i_postbox] = shindan_num
  }

  on_window_created do |i_window|
    @main_window = i_window
  end

  on_gui_postbox_join_widget do |i_postbox|
    # 診断以外で作られたPostboxでもイベントが飛んでくるので，それらは弾く．
    shindan_num = @shindan_num_of.fetch(i_postbox, nil)
    next if shindan_num.nil?

    postbox = Plugin.filtering(:gui_get_gtk_widget, i_postbox).first
    if postbox.nil?
      Plugin.activity(:error, "Postboxを取得できませんでした．")
      next
    end
    widget = postbox.widget_post
    widget.buffer.text = "(診断中)"
    widget.sensitive = false
    Thread.new {
      begin
        Net::HTTP.start('shindanmaker.com') do |http|
          http.read_timeout = UserConfig[:shindanmaker_timeout].to_i
          res = http.post("/#{shindan_num}", "u=#{UserConfig[:shindanmaker_name]}")
          doc = Nokogiri::HTML::parse(res.body)
          txt = doc.xpath('//textarea').first.inner_text
          widget.buffer.text = txt
          if postbox.respond_to? :refresh_buttons # 0.0.4以前でも動作するように
            postbox.refresh_buttons end
        end
      rescue
        notice "shindan failed: #{url}, #{$!}"
        Plugin.activity(:error, "診断がタイムアウトしました．")
        widget.buffer.text = ""
      ensure
        widget.sensitive = true
      end
    }
  end

  settings("診断メーカー") do
    adjustment("タイムアウト(sec)", :shindanmaker_timeout, 0, 60)
    input("ゆーざーねーむ",:shindanmaker_name)
  end
end
