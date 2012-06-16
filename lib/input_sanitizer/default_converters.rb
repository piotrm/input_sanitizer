require 'time'

module InputSanitizer
  class ConversionError < Exception
  end

  class IntegerConverter
    def call(value)
      cast = value.to_i
      if cast.to_s != value.to_s
        raise ConversionError.new("invalid integer")
      end
      cast
    end
  end

  class StringConverter
    def call(value)
      value.to_s
    end
  end

  class DateConverter
    ISO_RE = /\A\d{4}-?\d{2}-?\d{2}/

    def call(value)
      raise ConversionError.new("invalid time") unless value =~ ISO_RE
      Date.parse(value)
    rescue ArgumentError
      raise ConversionError.new("invalid iso8601 date")
    end
  end

  class TimeConverter
    ISO_RE = /\A\d{4}-?\d{2}-?\d{2}([T ]?\d{2}(:?\d{2}(:?\d{2})?)?)?\Z/

    def call(value)
      if value =~ ISO_RE
        strip_timezone(Time.parse(value))
      else
        raise ConversionError.new("invalid time")
      end
    rescue ArgumentError
      raise ConversionError.new("invalid time")
    end

    def strip_timezone(time)
      Time.utc(time.year, time.month, time.day, time.hour, time.min, time.sec)
    end
  end

  class BooleanConverter
    def call(value)
      vals = {
        true => true,
        false => false,
        'true' => true,
        'false' => false,
        '1' => true,
        '0' => false,
        'yes' => true,
        'no' => false,
      }
      if vals.has_key?(value)
        vals[value]
      else
        raise ConversionError.new("invalid boolean")
      end
    end
  end
end
