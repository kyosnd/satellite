module Satellite
  class Yaml
    def Yaml.encode value
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

    def Yaml.load path
      value = nil
      File::open( path, 'r' ) { |file|
        value = file.read.force_encoding( 'UTF-8' )
      }
      return value ? Yaml.parse( value ) : value
    end

    def Yaml.parse base
      return nil if base.nil? || !base.is_a?(String) || 0 == base.length
      # encode to utf-8 and change enter-code.
      yaml = Yaml.encode( base ).gsub( "\r", '' )
      # begin parse.
      parents = [Yaml.new]
      nest = 0
      last = nil
      lines = yaml.split "\n"
      lines.each { | line |
        next if line.nil? || 3 > line.size || '#' == line[0]
        key = line[0 .. line.index( ': ' ) - 1]
        value = line[line.index( ': ' ) + 2 .. line.size]
        arr = key.split( '  ' )
        key = arr.pop
        if nest < arr.size
          parents << last
        elsif nest > arr.size
          parents.pop
        end
        nest = arr.size
        last = Node.new key, value
        parents.last.add last
      }
      return parents.first
    end

    def initialize
      @children = []
    end
    def [] key
      @children.each { | child |
        return child.value if child.key == key
      }
      nil
    end
    def []= key, value
      @children.each { | child |
        return child.value = value if child.key == key
      }
      add key, value
    end
    def each
      @children.each { | child |
        yield child
      }
    end
    def add child
      child.parent = self if Node === child
      @children << child
    end
    def remove child
      child.parent = nil if Node === child
      @children.delete child
    end

    def to_s
      lines = []
      each { | child | Yaml.yaml lines, 0, child }
      lines.join "\n"
    end
    def Yaml.yaml lines, indent, node
      lines << "#{'  ' * indent}#{node.key}: #{node.value}"
      node.each { | child | Yaml.yaml lines, indent + 1, child }
    end
  end
  class Node < Yaml
    attr_accessor :parent, :key, :value
    def initialize key, value=nil
      super()
      @key = key
      @value = value
    end
  end
end
