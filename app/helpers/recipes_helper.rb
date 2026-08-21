module RecipesHelper
  # Bold an ingredient when it matches either the free-text query or the
  # ingredient filter the user typed.
  def highlight_ingredient?(ingredient_name, *terms)
    name = ingredient_name.to_s.downcase
    return false if name.blank?

    terms.any? { |term| term.present? && name.include?(term.to_s.downcase) }
  end
end
