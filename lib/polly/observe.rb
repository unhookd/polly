#

module Polly
  class Observe
    def initialize
      @max_channel_length = 0
      @channels = {}
      @err_color = "\x1b[38;2;255;0;0m"
      @out_color = "\x1b[38;2;0;255;0m"
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
      if bytes
        @channels[channel][1] << bytes
      end
    end

    def stack_stderr(channel, bytes)
      if bytes
        @channels[channel][2] << bytes
      end
    end

    def report_stdout(channel, bytes)
      stack_stdout(channel, bytes + "\n")
    end

    def report_stderr(channel, bytes)
      stack_stderr(channel, bytes + "\n")
    end

    def report_io(channel, stdout_bytes, stderr_bytes)
      stack_stdout(channel, stdout_bytes)
      stack_stderr(channel, stderr_bytes)
    end

    def flush(stdout_io, stderr_io)
      @channels.each { |channel, color_and_scanners|
        color, stdout_scanner, stderr_scanner = *color_and_scanners
        while stdout_scanner.check_until(/\n/)
          stdout_io.write(colorize(color, channel.ljust(@max_channel_length)) + " " + colorize(@out_color, "OUT: "))
          stdout_io.write(stdout_scanner.scan_until(/\n/))
        end

        while stderr_scanner.check_until(/\n/)
          stderr_io.write(colorize(color, channel.ljust(@max_channel_length)) + " " + colorize(@err_color, "ERR: "))
          stderr_io.write(stderr_scanner.scan_until(/\n/))
        end
      }
    end

    def colorize(color_code, chunk)
      color_code + chunk + "\x1b[0m"
    end
  end
end
