class PagesController < ApplicationController
  def random_recipe
    @recipe = Recipe.all.sample
  end
end
