require "kconv"

module Satellite

  class XElement < Hash
    Template = "<%1$s%2$s>%3$s</%1$s>%4$s"
    Template_SelfTag = "<%1$s%2$s />%3$s"
    attr_accessor :tag, :value, :base, :root, :unescape

    def XElement.encode value
      result = value.force_encoding( 'UTF-8' )
      return result if result.valid_encoding?
      begin
        result = result.encode( 'UTF-8', 'Shift_JIS' )
      rescue
        begin
          result = result.encode( 'UTF-8', 'EUC-JP' )
        rescue
          result = result.toutf8
        end
      end
      result.gsub( /\xE3\x80\x9C/, "\xEF\xBD\x9E" ).
             gsub( /\xE2\x88\x92/, "\xEF\xBC\x8D" )
    end

    def XElement.load path
      value = nil
      File::open( path, 'r' ) { |file|
        value = file.read.force_encoding( 'UTF-8' )
      }
      return value ? XElement.parse( value ) : value
    end

    def XElement.parse base
      return nil if base.nil? || !base.is_a?(String) || 0 == base.length

      # encode to utf-8
      xml = XElement.encode( base )

      # remove comment.
      metatags = []
      comments = []
      xml = xml.gsub( /<!--(.|[\r\n])+?-->/, '' )
      while /<\?([^>]|[\r\n])+?\?>/ =~ xml
        metatags << $&
        xml = xml.sub( /<\?(.|[\r\n])+?\?>/, '' )
      end
      while /<\!([^>]|[\r\n])+>/ =~ xml
        metatags << $&
        xml = xml.sub( /<\![^-][^-]([^>]|[\r\n])+>/, '' )
      end

      # close unsupported tags
      ['br', 'hr', 'img', 'link', 'meta'].each { |tag|
        xml = xml.gsub( Regexp.new( "<#{tag}>" ), "<#{tag}/>" )
        regex = Regexp.new( "<#{tag} ([^/>]*)>" )
        xml = xml.sub( regex, "<#{tag} #{$1}/>" ) while regex =~ xml
      }

      # result is created xelement.
      result = nil
      element = nil
      parents = []
      nest = -1
      # begin parse.
      sindex = xml.index('<')
      xml[sindex .. xml.length - sindex].split(/</).each { |str|
        # skip.
        next if '' == str.gsub( "\n", '' )
        if '/' != str[0]
          # begin tag.
          arr = str.split(/>/)
          tag = arr[0]
          value = arr[1]
          pics = tag.split(/ /)
          element = XElement.new( pics[0].gsub('/', ''), value )
          element.root = result
          if 1 < pics.length
            # attributes
            record = nil
            pics.each { |pic|
              if record.nil? && pic.index("=\"")
                if 2 == pic.count("\"")
                  vals = pic.split("\"")
                  element.store vals[0].gsub("=", ""), vals[1]
                  record = nil
                else
                  record = pic
                end
                next
              end
              if !record.nil?
                record << " " + pic
                if pic.index("\"")
                  vals = record.split("\"")
                  element.store vals[0].gsub("=", ""), vals[1]
                  record = nil
                end
              end
            }
          end
          if 0 > nest
            # root.
            result = element
            result.base = base
            metatags.each { |i| result.metatags << i }
            comments.each { |i| result.comments << i }
          else
            # node.
            parents[nest].add element
          end
          if '/' != tag[tag.length - 1]
            parents << element
            nest += 1
          end
        else
          # end tag.
          arr = str.split(/>/)
          tag = arr[0]
          value = arr[1]
          pics = tag.split(/ /)
          case pics[0].gsub('/', '')
            when 'br', 'hr', 'img', 'link', 'meta'
              # through
            else
              parents.delete_at nest
              nest -= 1
          end
          element.texts << value if value
        end
      }
      return result
    end

    def initialize tag, value=nil
      @tag = tag.to_s
      @value = ('' == value ? nil : value)
      @children = []
      @metatags = []
      @comments = []
      @texts = []
    end

    def children
      @children
    end
    def metatags
      @metatags
    end
    def comments
      @comments
    end
    def texts
      @texts
    end
    def count
      @children.size
    end
    def size
      count
    end

    def add item
      if item.instance_of? XElement
        @children << item
      else item.instance_of? Hash
        item.to_a.each { |key, value|
          self.store key, value
        }
      end
    end
    def remove target
      if target.instance_of? String
        @children.each { | child |
          target = child if child.tag == target
        }
      end
      @children.delete target
    end
    def base
      @base
    end
    def to_s
      xml
    end
    def escape value
      value.#gsub( /</, '&lt;' ).
            #gsub( />/, '&gt;' ).
            #gsub( /'/, '&apos;' ).
            #gsub( /"/, '&quot;' ).
            gsub( /&/, '&amp;' )
    end
    def xml unescape=nil
      unescape = @unescape unless @unescape.nil?
      inner = (@value.nil? ? '' : (unescape ? @value.to_s : escape( @value.to_s )))
      @children.each { |child|
        subxml = child.xml( unescape )
        inner << subxml
      }
      attr = ''
      to_a.each { |key, value|
        attr << " #{key}=\"#{value}\""
      }
      texts = @texts.join "\n"
      return Template % [ @tag, attr, inner, texts ]
    end
    def xhtml unescape=nil
      unescape = @unescape unless @unescape.nil?
      inner = (@value.nil? ? '' : (unescape ? @value.to_s : escape( @value.to_s )))
      @children.each { |child|
        subxhtml = child.xhtml( unescape )
        inner << subxhtml
      }
      attr = ''
      to_a.each { |key, value|
        attr << " #{key}=\"#{value}\""
      }
      texts = @texts.join "\n"
      return @metatags.join( "\n" ) + ( ('' == inner) ? 
                 Template_SelfTag % [ @tag, attr, texts ] : 
                 Template % [ @tag, attr, inner, texts ] )
    end
    def get tag
      @children.each { |child|
        return child if child.tag == tag
        element = child.get tag
        return element if element
      }
      return nil
    end
    def getValue tag
      @children.each { |child|
        return child.value if child.tag == tag
        value = child.getValue tag
        return value if value
      }
      return nil
    end
    def gets tag
      result = []
      @children.each { |child|
        result << child if child.tag == tag
        result += child.gets tag
      }
      return result
    end
    def getChildrenHash key=nil
      hash = Hash.new
      if key
        @children.each { |child|
          hash.store( child.getValue( key ), child )
        }
      else
        @children.each { |child|
          hash.store child.tag, child.value
        }
      end
      return hash
    end
    def deepCopy
      Marshal.load(  [ Marshal.dump( self ) ].pack("m").unpack("m")[0] )
    end
  end
end
