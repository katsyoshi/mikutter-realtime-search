# -*- coding: utf-8 -*-
# Search
# 現在のTwitterをStreaming APIでOR検索！

miquire :mui, 'timeline'

Plugin::create(:realtime_search) do
  @main = Gtk::TimeLine.new()
  @main.force_retrieve_in_reply_to = false
  @querybox = Gtk::Entry.new
  @querycount = Gtk::VBox.new(false,0)
  @searchbtn = Gtk::Button.new('検索')
  @queue_parse = SizedQueue.new(2)
  @queue_event = TimeLimitedQueue.new(4, 1){ |messages| Delayer.new(Delayer::LAST){ @main.add messages } }
  @querycount.closeup(Gtk::HBox.new(false, 0).pack_start(@querybox).closeup(@searchbtn))
  @container = Gtk::VBox.new(false,0).pack_start(@querycount,false).pack_start(@main, true)

  def keyword( keys )
    keys.split(/,|(\s+)/).map{|k| k.strip}.join(",")
  end

  def streaming_search( bw )
    Thread.new{
      loop{
        sleep(3)
        notice 'filter stream: connect'
        begin
          break if @pbzw != bw && @pbzw
          @pbzw = bw
          buzzword = keyword(bw)
          if !buzzword or buzzword.empty?
            sleep(60)
          else
            Plugin.call(:rewindstatus, "Searchワード: #{buzzword}")
            puts "Searchワード: #{buzzword}"
            timeout(60){
              # ほぼ確実にここ発行しすぎ
              @service.streaming(:filter_stream, :track => buzzword){ |word|
                @queue_parse.push word
              }
            }
          end
        rescue TimeoutError => e
        rescue => e
          warn e end
        notice 'filter stream: disconnected'
      }
      @pbzw = nil
    }
  end

  def display_search
    Thread.new{
      loop{
        json = @queue_parse.pop.strip
        p "JSON:"+json.to_s
        case json
        when /^\{.*\}$/
          messages = @service.__send__(:parse_json, json, :streaming_status) # rescue nil
          if messages.is_a? Enumerable
            messages.each{ |message|
              p message
              @queue_event.push message if message.is_a? Message
            }
          end
        end
      }
    }
  end
  #def search(word)
  Delayer.new {
    @service = Post.services.first
    Plugin.call(:mui_tab_regist, @container, 'Search')
    @searchbtn.signal_connect('clicked'){|elm|
      Gtk::Lock.synchronize do
        elm.sensitive = @querybox.sensitive = false
        @main.clear
        streaming_search(@querybox.text)
        # streaming_search(UserConfig[:realtime_search])
        display_search
        sleep(60) #検索開始から1分はまつ
        elm.sensitive = @querybox.sensitive = true
      end
    }
  }
  # end

  # search(UserConfig[:realtime_search])
end

