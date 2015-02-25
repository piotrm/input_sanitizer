require 'spec_helper'

class AddressSanitizer < InputSanitizer::V2::PayloadSanitizer
  string :city
  string :zip
end

class TagSanitizer < InputSanitizer::V2::PayloadSanitizer
  integer :id
  string :name
  nested :addresses, :sanitizer => AddressSanitizer, :collection => true
end

class TestedPayloadSanitizer < InputSanitizer::V2::PayloadSanitizer
  integer :array, :collection => true
  string :status, :allow => ['current', 'past']
  string :status_with_empty, :allow => ['', 'current', 'past']
  nested :address, :sanitizer => AddressSanitizer
  nested :tags, :sanitizer => TagSanitizer, :collection => true

  integer :integer_attribute, :minimum => 1, :maximum => 100
  string :string_attribute
  boolean :bool_attribute
  datetime :datetime_attribute

  url :website
  string :limited_collection, :collection => { :minimum => 1, :maximum => 2 }
end

class BlankValuesPayloadSanitizer < InputSanitizer::V2::PayloadSanitizer
  string :string, :required => true
  datetime :datetime, :allow_nil => false
  url :url, :allow_blank => false
end

describe InputSanitizer::V2::PayloadSanitizer do
  let(:sanitizer) { TestedPayloadSanitizer.new(@params) }
  let(:cleaned) { sanitizer.cleaned }

  describe "collections" do
    it "is invalid if collection is not an array" do
      @params = { :array => {} }
      sanitizer.should_not be_valid
    end

    it "is valid if collection is an array" do
      @params = { :array => [] }
      sanitizer.should be_valid
    end

    it "is invalid if there are too few elements" do
      @params = { :limited_collection => [] }
      sanitizer.should_not be_valid
    end

    it "is invalid if there are too many elements" do
      @params = { :limited_collection => ['bear', 'bear', 'bear'] }
      sanitizer.should_not be_valid
    end

    it "is valid when there are just enough elements" do
      @params = { :limited_collection => ['goldilocks'] }
      sanitizer.should be_valid
    end
  end

  describe "allow option" do
    it "is valid when given an allowed string" do
      @params = { :status => 'past' }
      sanitizer.should be_valid
    end

    it "is invalid when given an empty string" do
      @params = { :status => '' }
      sanitizer.should_not be_valid
      sanitizer.errors[0].field.should eq('/status')
    end

    it "is valid when given an allowed empty string" do
      @params = { :status_with_empty => '' }
      sanitizer.should be_valid
    end

    it "is invalid when given a disallowed string" do
      @params = { :status => 'current bad string' }
      sanitizer.should_not be_valid
      sanitizer.errors[0].field.should eq('/status')
    end
  end

  describe "minimum and maximum options" do
    it "is invalid if integer is lower than the minimum" do
      @params = { :integer_attribute => 0 }
      sanitizer.should_not be_valid
    end

    it "is invalid if integer is greater than the maximum" do
      @params = { :integer_attribute => 101 }
      sanitizer.should_not be_valid
    end

    it "is valid when integer is within given range" do
      @params = { :limited_collection => ['goldilocks'] }
      sanitizer.should be_valid
    end
  end

  describe "strict param checking" do
    it "is invalid when given extra params" do
      @params = { :extra => 'test', :extra2 => 1 }
      sanitizer.should_not be_valid
      sanitizer.errors.count.should eq(2)
    end

    it "is invalid when given extra params in a nested sanitizer" do
      @params = { :address => { :extra => 0 }, :tags => [ { :extra2 => 1 } ] }
      sanitizer.should_not be_valid
      sanitizer.errors.map(&:field).should contain_exactly('/address/extra', '/tags/0/extra2')
    end
  end

  describe "strict type checking" do
    it "is invalid when given string instead of integer" do
      @params = { :integer_attribute => '1' }
      sanitizer.should_not be_valid
      sanitizer.errors[0].field.should eq('/integer_attribute')
    end

    it "is valid when given an integer" do
      @params = { :integer_attribute => 50 }
      sanitizer.should be_valid
      sanitizer[:integer_attribute].should eq(50)
    end

    it "is valid when given nil for an integer" do
      @params = { :integer_attribute => nil }
      sanitizer.should be_valid
      sanitizer[:integer_attribute].should be_nil
    end

    it "is invalid when given integer instead of string" do
      @params = { :string_attribute => 0 }
      sanitizer.should_not be_valid
      sanitizer.errors[0].field.should eq('/string_attribute')
    end

    it "is valid when given a string" do
      @params = { :string_attribute => '#@!#%#$@#ad' }
      sanitizer.should be_valid
      sanitizer[:string_attribute].should eq('#@!#%#$@#ad')
    end

    it "is invalid when given 'yes' as a bool" do
      @params = { :bool_attribute => 'yes' }
      sanitizer.should_not be_valid
      sanitizer.errors[0].field.should eq('/bool_attribute')
    end

    it "is valid when given true as a bool" do
      @params = { :bool_attribute => true }
      sanitizer.should be_valid
    end

    it "is valid when given false as a bool" do
      @params = { :bool_attribute => false }
      sanitizer.should be_valid
    end

    it "is invalid when given an incorrect datetime" do
      @params = { :datetime_attribute => "2014-08-2716:32:56Z" }
      sanitizer.should_not be_valid
      sanitizer.errors[0].field.should eq('/datetime_attribute')
    end

    it "is valid when given a correct datetime" do
      @params = { :datetime_attribute => "2014-08-27T16:32:56Z" }
      sanitizer.should be_valid
    end

    it "is valid when given a 'forever' timestamp" do
      @params = { :datetime_attribute => "9999-12-31T00:00:00Z" }
      sanitizer.should be_valid
    end

    it "is valid when given a correct URL" do
      @params = { :website => "https://google.com" }
      sanitizer.should be_valid
      sanitizer[:website].should eq("https://google.com")
    end

    it "is invalid when given an invalid URL" do
      @params = { :website => "ht:/google.com" }
      sanitizer.should_not be_valid
    end

    it "is invalid when given an invalid URL that contains a valid URL" do
      @params = { :website => "watwat http://google.com wat" }
      sanitizer.should_not be_valid
    end

    describe "blank and required values" do
      let(:sanitizer) { BlankValuesPayloadSanitizer.new(@params) }
      let(:defaults) { { :string => 'zz' } }

      it "is invalid if required string is blank" do
        @params = { :string => ' ' }
        sanitizer.should_not be_valid
        sanitizer.errors[0].should be_an_instance_of(InputSanitizer::ValueMissingError)
      end

      it "is invalid if non-nil datetime is null" do
        @params = defaults.merge({ :datetime => nil })
        sanitizer.should_not be_valid
        sanitizer.errors[0].should be_an_instance_of(InputSanitizer::ValueMissingError)
      end

      it "is valid if non-nil datetime is blank" do
        @params = defaults.merge({ :datetime => '' })
        sanitizer.should be_valid
      end

      it "is invalid if non-blank url is nil" do
        @params = defaults.merge({ :url => nil })
        sanitizer.should_not be_valid
        sanitizer.errors[0].should be_an_instance_of(InputSanitizer::ValueMissingError)
      end

      it "is invalid if non-blank url is blank" do
        @params = defaults.merge({ :url => '' })
        sanitizer.should_not be_valid
        sanitizer.errors[0].should be_an_instance_of(InputSanitizer::ValueMissingError)
      end
    end

    describe "nested checking" do
      describe "simple array" do
        it "returns JSON pointer for invalid fields" do
          @params = { :array => [1, 'z', '3', 4] }
          sanitizer.errors.length.should eq(2)
          sanitizer.errors.map(&:field).should contain_exactly('/array/1', '/array/2')
        end
      end

      describe "nested object" do
        it "returns JSON pointer for invalid fields" do
          @params = { :address => { :city => 0, :zip => 1 } }
          sanitizer.errors.length.should eq(2)
          sanitizer.errors.map(&:field).should contain_exactly('/address/city', '/address/zip')
        end
      end

      describe "array of nested objects" do
        it "returns JSON pointer for invalid fields" do
          @params = { :tags => [ { :id => 'n', :name => 1 }, { :id => 10, :name => 2 } ] }
          sanitizer.errors.length.should eq(3)
          sanitizer.errors.map(&:field).should contain_exactly(
            '/tags/0/id',
            '/tags/0/name',
            '/tags/1/name'
          )
        end
      end

      describe "array of nested objects that have array of nested objects" do
        it "returns JSON pointer for invalid fields" do
          @params = { :tags => [
            { :id => 'n', :addresses => [ { :city => 0 }, { :city => 1 } ] },
            { :name => 2, :addresses => [ { :city => 3 } ] },
          ] }
          sanitizer.errors.length.should eq(5)
          sanitizer.errors.map(&:field).should contain_exactly(
            '/tags/0/id',
            '/tags/0/addresses/0/city',
            '/tags/0/addresses/1/city',
            '/tags/1/name',
            '/tags/1/addresses/0/city'
          )

          ec = sanitizer.error_collection
          ec.length.should eq(5)
        end
      end
    end
  end
end
