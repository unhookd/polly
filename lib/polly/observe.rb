#

module Polly
  class Observe
    def initialize
      @max_channel_length = 0
      @channels = {}
      @err_color = "\x1b[38;2;255;0;0m"
      @out_color = "\x1b[38;2;0;255;0m"
      @newline_regex = Regexp.new($/)
      @nol_chunk_size = 64
    end

    def rainbow(freq, i)
     red   = Math.sin(freq*i + 0) * 127 + 128
     green = Math.sin(freq*i + 2*Math::PI/3) * 127 + 128
     blue  = Math.sin(freq*i + 4*Math::PI/3) * 127 + 128
     "%02X%02X%02X" % [ red, green, blue ]
    end

    def register_channels(channels)
      channels.each_with_index { |channel, i|
        if channel.length > @max_channel_length
          @max_channel_length = channel.length
        end

        color_hex = rainbow(channels.length / 3.0, i*3.0)
        red, green, blue = color_hex.each_char.each_slice(2).map { |hex_color| hex_color.join.to_i(16) }
        color = "\x1b[38;2;#{red};#{green};#{blue}m"

        @channels[channel] = [
          color,
          StringScanner.new(""),
          StringScanner.new("")
        ]
      }
    end

    def stack_stdout(channel, bytes)
      if bytes && @channels[channel]
        @channels[channel][1] << bytes
      else
        puts "unknown #{bytes.inspect} -- #{channel} -- #{@channels.keys}" if bytes
        true
      end
    end

    def stack_stderr(channel, bytes)
      if bytes
        @channels[channel][2] << bytes
      end
    end

    def report_stdout(channel, bytes)
      stack_stdout(channel, bytes + $/)
    end

    def report_stderr(channel, bytes)
      stack_stderr(channel, bytes + $/)
    end

    def report_io(channel, stdout_bytes, stderr_bytes)
      stack_stdout(channel, stdout_bytes)
      stack_stderr(channel, stderr_bytes)
    end

    def flush(stdout_io, stderr_io, final_flush = false)
      @channels.each { |channel, color_and_scanners|
        color, stdout_scanner, stderr_scanner = *color_and_scanners
        while stdout_scanner.check_until(@newline_regex)
          found_line = stdout_scanner.scan_until(@newline_regex)
          #puts [channel, found_line].inspect
          stdout_io.write(colorize(color, channel.ljust(@max_channel_length)) + " " + colorize(@out_color, "OUT: "))
          stdout_io.write(found_line)
        end

        while stderr_scanner.check_until(@newline_regex)
          found_line = stderr_scanner.scan_until(@newline_regex)
          #puts [channel, found_line].inspect
          stderr_io.write(colorize(color, channel.ljust(@max_channel_length)) + " " + colorize(@err_color, "ERR: "))
          stderr_io.write(found_line)
        end

        if stdout_scanner.rest_size > 0 || final_flush
          while true
            fetched_chunk = stdout_scanner.peek(@nol_chunk_size)
            break if fetched_chunk.empty?
            stdout_scanner.pos = stdout_scanner.pos + fetched_chunk.length
            stdout_io.write(colorize(color, channel.ljust(@max_channel_length)) + " " + colorize(@out_color, "OUT: "))
            stdout_io.write(fetched_chunk)
            stdout_io.write($/)
          end
        end

        if stderr_scanner.rest_size > 0 || final_flush
          while true
            fetched_chunk = stderr_scanner.peek(@nol_chunk_size)
            break if fetched_chunk.empty?
            stderr_scanner.pos = stderr_scanner.pos + fetched_chunk.length
            stderr_io.write(colorize(color, channel.ljust(@max_channel_length)) + " " + colorize(@err_color, "ERR: "))
            stderr_io.write(fetched_chunk)
            stderr_io.write($/)
          end
        end
      }
    end

    def colorize(color_code, chunk)
      color_code + chunk + "\x1b[0m"
    end
  end
end
