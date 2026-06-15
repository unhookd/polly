module Polly
  class DocumentStreamHandler < Psych::TreeBuilder
    def initialize &block
      super
      @block = block
    end
  
    def end_document implicit_end = !streaming?
      @last.implicit_end = implicit_end
      @block.call pop
    end
  
    def start_document version, tag_directives, implicit
      n = Psych::Nodes::Document.new version, tag_directives, implicit
      push n
    end
  end
end
