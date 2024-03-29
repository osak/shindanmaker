#-*- coding: utf-8

require 'net/https'
require 'uri'
require 'nokogiri'

require_relative 'model' if Environment::VERSION >= [3, 6, 0, 0]

Plugin.create(:shindanmaker) do
  UserConfig[:shindanmaker_timeout] ||= 10
  UserConfig[:shindanmaker_name] ||= Service.primary.user rescue nil
  @main_window = nil
  @shindan_num_of = {}

  def user_agent
    "mikutter-shindanmaker/#{spec[:version]} (https://github.com/osak/shindanmaker)"
  end

  def start_shindan(shindan_num)
    # Postboxをトップレベルウィンドウに追加してから実体が取得可能になるには，Pluginの発火を待たないといけない．
    # よって診断番号だけ保存しておいて，Postboxが登録完了してから診断を開始するようにする．
    i_postbox = Plugin::GUI::Postbox.instance
    i_postbox.options[:delegate_other] = false
    @main_window << i_postbox
    @shindan_num_of[i_postbox] = shindan_num
  end

  def begin_session(http, shindan_num)
    res = http.get("/#{shindan_num}", { 'User-Agent': user_agent })
    cookie = res.get_fields('Set-Cookie').map { |s| s[0...s.index(';')].split('=') }.to_h
    doc = Nokogiri::HTML::parse(res.body)
    { cookie: cookie, token: doc.xpath('//*[@id="shindanForm"]/input[@name="_token"]').first[:value] }
  end

  if Environment::VERSION < [3, 6, 0, 0]
      Gtk::TimeLine.addopenway(/^https?:\/\/shindanmaker\.com\/[0-9]+/) { |url, cancel|
        begin
          match = url.to_s.match(/^https?:\/\/shindanmaker\.com\/([0-9]+)/)
          shindan_num = match[1]
        rescue
          Plugin.activity(:error, "診断URLが処理できない形式です： #{url}")
          cancel.call
          next
        end

        start_shindan(shindan_num)
      }
  else
    intent Plugin::ShindanMaker::Shindan, label: '診断メーカーで診断' do |intent_token|
      start_shindan(intent_token.model.id)
    end
  end

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
    class << postbox
      def destructible?; true; end
    end
    widget = postbox.widget_post
    widget.buffer.text = "(診断中)"
    widget.sensitive = false
    Thread.new {
      begin
        http = Net::HTTP.new('shindanmaker.com', 443)
        http.use_ssl = true
        http.read_timeout = UserConfig[:shindanmaker_timeout].to_i
        http.start do
          session = begin_session(http, shindan_num)
          res = http.post("/#{shindan_num}", "shindanName=#{UserConfig[:shindanmaker_name]}&_token=#{session[:token]}",
                          { Cookie: session[:cookie].map { |k, v| "#{k}=#{v}" }.join('; '), 'User-Agent': user_agent })
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
