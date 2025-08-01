module ApplicationHelper
  def app_name
    Rails.application.config.app_name
  end

  def app_logo
    return nil if Rails.application.config.app_logo.blank?
    
    if Rails.application.config.app_logo.ends_with?('.svg')
      content_tag(:div, 
        File.read(Rails.root.join('app', 'assets', 'images', Rails.application.config.app_logo)).html_safe,
        style: "height: 48px; width: auto; max-width: 200px;"
      )
    else
      image_tag Rails.application.config.app_logo, 
        style: "height: 48px; width: auto; max-width: 200px;",
        alt: app_name
    end
  end

  def app_brand
    if Rails.application.config.app_logo.present?
      app_logo
    else
      content_tag(:span, class: "brand-content") do
        concat content_tag(:svg, 
          content_tag(:path, "", d: "M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"),
          width: "24", height: "24", fill: "currentColor", viewBox: "0 0 24 24"
        )
        concat " #{app_name}"
      end
    end
  end
end
