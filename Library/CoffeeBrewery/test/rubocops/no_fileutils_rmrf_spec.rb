# typed: true
# frozen_string_literal: true

require "rubocops/no_fileutils_rmrf"

RSpec.describe RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf do
  subject(:cop) { described_class.new }

  describe "rm_rf" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        rm_rf("path/to/directory")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
        FileUtils.rm_rf("path/to/directory")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
      RUBY
    end

    it "autocorrects" do
      corrected = autocorrect_source(<<~RUBY)
        rm_rf("path/to/directory")
        FileUtils.rm_rf("path/to/other/directory")
      RUBY

      expect(corrected).to eq(<<~RUBY)
        rm_r("path/to/directory")
        FileUtils.rm_r("path/to/other/directory")
      RUBY
    end
  end

  describe "rm_f" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        rm_f("path/to/directory")
        ^^^^^^^^^^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
        FileUtils.rm_f("path/to/other/directory")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
      RUBY
    end

    it "autocorrects" do
      corrected = autocorrect_source(<<~RUBY)
        rm_f("path/to/directory")
        FileUtils.rm_f("path/to/other/directory")
      RUBY

      expect(corrected).to eq(<<~RUBY)
        rm("path/to/directory")
        FileUtils.rm("path/to/other/directory")
      RUBY
    end
  end

  describe "rmtree" do
    it "registers an offense" do
      expect_offense(<<~RUBY)
        rmtree("path/to/directory")
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
        other_dir = Pathname("path/to/other/directory")
        other_dir.rmtree
        ^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
        def buildpath
          Pathname("path/to/yet/another/directory")
        end
        buildpath.rmtree
        ^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
        (path/"here").rmtree
        ^^^^^^^^^^^^^^^^^^^^ CoffeeBrewery/NoFileutilsRmrf: #{RuboCop::Cop::CoffeeBrewery::NoFileutilsRmrf::MSG}
      RUBY
    end

    it "autocorrects" do
      corrected = autocorrect_source(<<~RUBY)
        rmtree("path/to/directory")
        other_dir = Pathname("path/to/other/directory")
        other_dir.rmtree
        def buildpath
          Pathname("path/to/yet/another/directory")
        end
        buildpath.rmtree
        (path/"here").rmtree
      RUBY

      expect(corrected).to eq(<<~RUBY)
        rm_r("path/to/directory")
        other_dir = Pathname("path/to/other/directory")
        FileUtils.rm_r(other_dir)
        def buildpath
          Pathname("path/to/yet/another/directory")
        end
        FileUtils.rm_r(buildpath)
        FileUtils.rm_r(path/"here")
      RUBY
    end
  end
end
