# -*- encoding: utf-8 -*-
# To test use 
# rake TEST=test/test_search.rb
require 'test/unit'
require 'code_zauker'
require 'pdf/reader'

# See ri Test::Unit::Assertions
# for assertion documentation
class FileScannerBasicSearch < Test::Unit::TestCase

  # The pdf-reader add spuious space at the end of the text...
  # perhaps it is some \r char?!...
  def test_pdf_reader_simple()
    reader = PDF::Reader.new("test/fixture/simple_test.pdf")
    puts "PDF Ver: #{reader.pdf_version} INFO:#{reader.info}: \n#{reader.metadata}"
    assert_equal "Giorgi Giovanni", reader.info[:Author]    
    page1=reader.page(1).text    
    #puts "Page 1\n:::#{page1}:::"
    lines=page1.split("\n")
    assert_equal "Simple PDF File generated with MSOffice 2010 ",lines[0],"Error. PDF Reader output:#{lines[0]}"
    assert_equal lines[0][-1,1]," ", "Trailing whitespace bug expected"
    assert_equal "Test case for Code Zauker v0.0.4+ ",lines[1]
    # 4th row is about accents...
    #puts ":#{lines[3]}:"
    accentLine=lines[3].strip()
    assert_equal accentLine,"àèéìòù"
    assert_equal "UTF-8",accentLine.encoding().name
    assert_equal true,accentLine.valid_encoding?()
  end

  def test_is_pdf()
    u=CodeZauker::Util.new()
    assert_equal true, u.is_pdf?("Case_crazy.PdF")
  end

end
 
