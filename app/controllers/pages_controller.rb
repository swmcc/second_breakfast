class PagesController < ApplicationController
  def random_recipe
    @recipe = Recipe.all.sample
  end

  def privacy
  end

  def terms
  end
end
