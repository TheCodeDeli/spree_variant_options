require 'test_helper'

module Spree
  class WishedProduct
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    attr_accessor :variant_id

    def persisted?
      false
    end
  end
end

class ProductTest < ActionDispatch::IntegrationTest

  context 'with track inventory levels' do

    setup do
      Spree::Config[:track_inventory_levels] = true
      Spree::Config[:allow_backorders] = false
      @product = Factory(:product)
      @size = Factory(:option_type)
      @color = Factory(:option_type, :name => "Color")
      @s = Factory(:option_value, :presentation => "S", :option_type => @size)
      @m = Factory(:option_value, :presentation => "M", :option_type => @size)
      @red = Factory(:option_value, :name => "Color", :presentation => "Red", :option_type => @color)
      @green = Factory(:option_value, :name => "Color", :presentation => "Green", :option_type => @color)
      @variant1 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@s, @red], :on_hand => 0)
      @variant2 = Factory(:variant, :product => @product, :option_values => [@s, @green], :on_hand => 0)
      @variant3 = Factory(:variant, :product => @product, :option_values => [@m, @red], :on_hand => 0)
      @variant4 = Factory(:variant, :product => @product, :price => 35.99, :option_values => [@m, @green], :on_hand => 1)

      Deface::Override.new( :virtual_path => "spree/products/show",
      :name => "add_other_form_to_spree_variant_options",
      :insert_after => "div#cart-form",
      :text => '<div id="wishlist-form"><%= form_for Spree::WishedProduct.new, :url => "foo", :html => {:"data-form-type" => "variant"} do |f| %><%= f.hidden_field :variant_id, :value => @product.master.id %><button type="submit"><%= t(:add_to_wishlist) %></button><% end %></div>')
      SpreeVariantOptions::VariantConfig.default_instock = false
    end

    should 'disallow choose out of stock variants' do

      reset_spree_variant_options_preferences do |config|
        config.allow_select_outofstock = false
      end

      visit spree.product_path(@product)

      # variant options are not selectable
      within("#product-variants") do
        size = find_link('S')
        size.click
        assert !size["class"].include?("selected")
        color = find_link('Green')
        color.click
        assert !color["class"].include?("selected")
      end

      # add to cart button is still disabled
      assert_equal "true", find_button("Add To Cart")["disabled"]
      # add to wishlist button is still disabled
      assert_equal "true", find_button("Add To Wishlist")["disabled"]
    end

    should 'allow choose out of stock variants' do
      reset_spree_variant_options_preferences do |config|
        config.allow_select_outofstock = true
      end

      visit spree.product_path(@product)

      # variant options are selectable
      within("#product-variants") do
        size = find_link('M')
        size.click
        assert size["class"].include?("selected")

        size = find_link('S')
        size.click
        assert size["class"].include?("selected")


        color = find_link('Green')
        color.click
        assert color["class"].include?("selected")
      end
      # add to cart button is still disabled
      assert_equal "true", find_button("Add To Cart")["disabled"]
      # add to wishlist button is enabled

      assert_nil find_button("Add To Wishlist")["disabled"]
    end

    should "choose in stock variant" do
      visit spree.product_path(@product)
      within("#product-variants") do
        size = find_link('M')
        size.click
        assert size["class"].include?("selected")
        color = find_link('Green')
        color.click
        assert color["class"].include?("selected")
      end
      # add to cart button is enabled
      assert_nil find_button("Add To Cart")["disabled"]
      # add to wishlist button is enabled
      assert_nil find_button("Add To Wishlist")["disabled"]
    end

    should "should select first instock variant when default_instock is true" do
      SpreeVariantOptions::VariantConfig.default_instock = true

      visit spree.product_path(@product)

      within("#product-variants") do
        size = find_link('M')
        assert size["class"].include?("selected")
        color = find_link('Green')
        assert color["class"].include?("selected")
      end

      # add to cart button is enabled
      assert_nil find_button("Add To Cart")["disabled"]
      within("span.price.selling") do
        assert page.has_content?("$35.99")
      end
    end

    should 'allow choose on demand' do
      @variant1.update_attribute :on_demand, true

      visit spree.product_path(@product)

      within("#product-variants") do
        size = find_link('S')
        size.click
        assert size["class"].include?("selected")
        color = find_link('Red')
        color.click
        assert color["class"].include?("selected")
      end

      # add to cart button is enabled
      assert_nil find_button("Add To Cart")["disabled"]
      within("span.price.selling") do
        assert page.has_content?("$32.99")
      end

    end

    should 'allow to choose on demand even with 3 option types' do
      @access = Factory(:option_type, :name => "Accessory")
      @tie = Factory(:option_value, :presentation => "Tie", :option_type => @access)
      @belt = Factory(:option_value, :presentation => "Belt", :option_type => @access)
      @product.variants.destroy_all
      @variant1 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@s, @red, @belt], :on_demand => true)
      @variant2 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@m, @red, @belt], :on_demand => false, :on_hand => 0)
      @variant3 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@s, @red, @tie], :on_demand => false, :on_hand => 0)
      @variant4 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@m, @red, @tie], :on_demand => true)
      @variant5 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@s, @green, @belt], :on_demand => true)
      @variant6 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@m, @green, @belt], :on_demand => false, :on_hand => 0)
      @variant7 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@s, @green, @tie], :on_demand => false, :on_hand => 0)
      @variant8 = Factory(:variant, :product => @product, :price => 32.99, :option_values => [@m, @green, @tie], :on_demand => true)

      visit spree.product_path(@product)

      within("#product-variants") do
        debugger
        size = find_link('M')
        size.click
        assert size["class"].include?("selected")
        color = find_link('Red')
        color.click
        assert color["class"].include?("selected")
        access = find_link('Tie')
        access.click
        assert access["class"].include?("selected")
      end

      # add to cart button is enabled
      assert_nil find_button("Add To Cart")["disabled"]
    end

    def teardown
      # reset preferences to default values
      SpreeVariantOptions::VariantConfig.allow_select_outofstock = false
      SpreeVariantOptions::VariantConfig.default_instock = false
    end
  end

  context 'without inventory tracking' do

    setup do
      reset_spree_preferences do |config|
        config.track_inventory_levels = false
        config.allow_backorders = false
      end
      @product = Factory(:product)
      @size = Factory(:option_type)
      @color = Factory(:option_type, :name => "Color")
      @s = Factory(:option_value, :presentation => "S", :option_type => @size)
      @red = Factory(:option_value, :name => "Color", :presentation => "Red", :option_type => @color)
      @green = Factory(:option_value, :name => "Color", :presentation => "Green", :option_type => @color)
      @variant1 = @product.variants.create({:option_values => [@s, @red], :price => 10, :cost_price => 5}, :without_protection => true)
      @variant2 = @product.variants.create({:option_values => [@s, @green], :price => 10, :cost_price => 5}, :without_protection => true)
    end

    should "choose variant with track_inventory_levels to false" do

      visit spree.product_path(@product)
      within("#product-variants") do
        # debugger
        size = find_link('S')
        size.click
        assert size["class"].include?("selected")
        color = find_link('Red')
        color.click
        assert color["class"].include?("selected")
      end
      # add to cart button is enabled
      assert_nil find_button("Add To Cart")["disabled"]
      # add to wishlist button is enabled
      assert_nil find_button("Add To Wishlist")["disabled"]
    end
  end
end