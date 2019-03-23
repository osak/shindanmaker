# -*- coding: utf-8 -*-

module Plugin::ShindanMaker
  class Shindan < Diva::Model
    register :shindanmaker_shindan, name: '診断メーカー'

    field.int :id, required: true

    handle %r[^https?://shindanmaker\.com/[0-9]+] do |uri|
      begin
        match = uri.to_s.match(/^https?:\/\/shindanmaker\.com\/([0-9]+)/)
        Plugin::ShindanMaker::Shindan.new(id: match[1])
      rescue
        raise Diva::DivaError, "診断URLが処理できない形式です： #{uri}"
      end
    end

    def uri
      Diva::URI.new("https://shindanmaker.com/#{id}")
    end
  end
end
