require 'test_helper'

class ExtractImagesTest < Test::Unit::TestCase

  def test_basic_image_extraction
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => :gif, :size => "250x", :output => OUTPUT)
    assert Dir["#{OUTPUT}/*"] == ['test/output/obama_arts_1.gif', 'test/output/obama_arts_2.gif']
  end
  
  def test_image_extraction_with_different_name
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => :gif, :size => "250x", :output => OUTPUT, :out_file_name => "american_arts")
    assert Dir["#{OUTPUT}/*"] == ["test/output/american_arts_2.gif", "test/output/american_arts_1.gif"]
  end

  def test_image_formatting
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => [:jpg, :gif], :size => "250x", :output => OUTPUT)
    assert Dir["#{OUTPUT}/*.gif"].length == 2
    assert Dir["#{OUTPUT}/*.jpg"].length == 2
  end

  def test_page_ranges
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => :gif, :size => "50x", :pages => 2, :output => OUTPUT)
    assert Dir["#{OUTPUT}/*.gif"] == ["#{OUTPUT}/obama_arts_2.gif"]
  end

  def test_image_sizes
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => :gif, :rolling => true, :size => ["150x", "50x"], :output => OUTPUT)
    assert File.size("#{OUTPUT}/50x/obama_arts_1.gif") < File.size("#{OUTPUT}/150x/obama_arts_1.gif")
  end

  def test_encrypted_images
    Docsplit.extract_images('test/fixtures/encrypted.pdf', :format => :gif, :size => "50x", :output => OUTPUT)
    assert File.size("#{OUTPUT}/encrypted_1.gif") > 100
  end

  def test_password_protected_extraction
    assert_raises(ExtractionFailed) do
      Docsplit.extract_images('test/fixtures/completely_encrypted.pdf')
    end
  end

  def test_repeated_extraction_in_the_same_directory
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => :gif, :size => "250x", :output => OUTPUT)
    assert Dir["#{OUTPUT}/*"] == ['test/output/obama_arts_1.gif', 'test/output/obama_arts_2.gif']
    Docsplit.extract_images('test/fixtures/obama_arts.pdf', :format => :gif, :size => "250x", :output => OUTPUT)
    assert Dir["#{OUTPUT}/*"] == ['test/output/obama_arts_1.gif', 'test/output/obama_arts_2.gif']
  end

end
