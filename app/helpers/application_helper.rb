module ApplicationHelper
  def signed_in?
    user_signed_in?
  end

  # Declares the breadcrumb trail for a page. Each crumb is [label, path];
  # omit the path on the final crumb (it is the current page).
  #
  #   <% breadcrumbs ["Recipes", recipes_path], [@recipe.title] %>
  #
  # The layout picks the result up via `yield :breadcrumbs`.
  def breadcrumbs(*crumbs)
    content_for :breadcrumbs, render("shared/breadcrumbs", crumbs: crumbs)
  end

  # DOM id of the input for +attribute+, matching what form builders generate,
  # so error-summary links can jump straight to the offending field.
  def field_dom_id(object, attribute)
    reflection = object.class.try(:reflect_on_association, attribute)
    attribute = reflection.foreign_key if reflection&.belongs_to?

    "#{object.model_name.param_key}_#{attribute}"
  end

  def field_error_dom_id(object, attribute)
    "#{field_dom_id(object, attribute)}_error"
  end

  # Attributes to splat onto an input so assistive tech knows it is invalid
  # and which message describes it.
  #
  #   <%= form.text_field :title, **field_error_attributes(recipe, :title) %>
  def field_error_attributes(object, attribute)
    return {} unless object.errors.include?(attribute)

    { "aria-invalid": "true", "aria-describedby": field_error_dom_id(object, attribute) }
  end

  # Border/ring classes for an input, reddened when the field is invalid.
  def field_border_classes(object, attribute)
    if object.errors.include?(attribute)
      "border-red-700 ring-1 ring-red-700"
    else
      "border-gray-300"
    end
  end
end
