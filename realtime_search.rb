# -*- coding: utf-8 -*-
# Search
# 現在のTwitterをStreaming APIでOR検索！

miquire :mui, 'timeline'

Plugin::create(:realtime_search) do
  @main = Gtk::TimeLine.new()
  @main.force_retrieve_in_reply_to = false
  @closebtn = Gtk::Button.new.add(Gtk::WebIcon.new(MUI::Skin.get('close.png'), 16, 16))
  @querybox = Gtk::Entry.new
  @querycount = Gtk::VBox.new(false,0)
  @searchbtn = Gtk::Button.new('検索')
  @queue_parse = SizedQueue.new(2)
  @queue_event = TimeLimitedQueue.new(4, 1){|messages|
    Delayer.new(Delayer::LAST){ @main.add messages }
  }
  @querycount.closeup(Gtk::HBox.new.pack_start(@querybox).closeup(@searchbtn).closeup(@closebtn))
  @container = Gtk::VBox.new(false,0).pack_start(@querycount,false).pack_start(@main, true)

  @streaming_thread = nil

  def keyword( keys )
    keys.split(/,|\s/).map{|k| k.strip}.join(",")
  end

  def stop_search
    notice 'kill the previous thread'
    Thread.kill(@streaming_thread)
    @streaming_thread = nil
  end

  def streaming_search(bw)
    stop_search if @streaming_thread

    buzzword = keyword(bw)
    if !buzzword or buzzword.empty?
      Plugin.call(:rewindstatus, "Searchワードが空みたいよ")
      return
    end

    @streaming_thread = Thread.new{
      notice 'filter stream: connect'
      begin
        Plugin.call(:rewindstatus, "Searchワード: #{buzzword}")
        STDERR.puts "Searchワード: #{buzzword}"
        @service.streaming(:filter_stream, :track => buzzword){|word|
          @queue_parse.push word
        }
      rescue => e
        warn e
      end
      notice 'filter stream: disconnected'
    }
  end

  def display_search
    Thread.new{
      loop{
        json = @queue_parse.pop.strip
        p "JSON:"+json.to_s
        case json
        when /^\{.*\}$/
          messages = @service.__send__(:parse_json, json, :streaming_status)
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

  Delayer.new do
    @service = Post.services.first
    Plugin.call(:mui_tab_regist, @container, 'Search')
    @searchbtn.signal_connect('clicked'){|elm|
      @main.clear
      streaming_search(@querybox.text)
      display_search
    }
    @closebtn.signal_connect('clicked') { stop_search }
  end
end

