# Read-only access to a recipe through its non-guessable share token.
#
# This is an "anyone with the link" grant: the token is the capability, so it
# works while signed out and it deliberately reaches private recipes too — that
# is the point of handing someone a share link. The UI only offers the link to
# people who can already see the recipe, and the recipe page warns owners of
# private recipes what the link does.
class SharedRecipesController < ApplicationController
  before_action :set_recipe

  # GET /r/:token
  def show
    render "recipes/shared"
  end

  # GET /r/:token/print
  def print
    render "recipes/print", layout: "print"
  end

  private

  def set_recipe
    @recipe = Recipe.includes(:category).find_by!(public_token: params[:token].to_s)
    @shared = true
  end
end
