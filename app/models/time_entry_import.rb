class TimeEntryImport < Import
  def self.menu_item
    :time_entries
  end

  def self.authorized?(user)
    user.allowed_to?(:log_time, nil, :global => true)
  end

  # Returns the objects that were imported
  def saved_objects
    TimeEntry.where(:id => saved_items.pluck(:obj_id)).order(:id).preload(:activity, :project, :issue => [:tracker, :priority, :status])
  end

  def mappable_custom_fields
    TimeEntryCustomField.all
  end

  def allowed_target_projects
    Project.allowed_to(user, :log_time).order(:lft)
  end

  def allowed_target_activities
    project.activities
  end

  def project
    project_id = mapping['project_id'].to_i
    allowed_target_projects.find_by_id(project_id) || allowed_target_projects.first
  end

  def activity
    if mapping['activity'].to_s =~ /\Avalue:(\d+)\z/
      activity_id = $1.to_i
      allowed_target_activities.find_by_id(activity_id)
    end
  end

  private


  def build_object(row, item)
    object = TimeEntry.new
    object.user = user

    activity_id = nil
    if activity
      activity_id = activity.id
    elsif activity_name = row_value(row, 'activity')
      activity_id = allowed_target_activities.named(activity_name).first.try(:id)
    end

    attributes = {
      :project_id  => project.id,
      :activity_id => activity_id,

      :issue_id    => row_value(row, 'issue_id'),
      :spent_on    => row_date(row, 'spent_on'),
      :hours       => row_value(row, 'hours'),
      :comments    => row_value(row, 'comments')
    }

    attributes['custom_field_values'] = object.custom_field_values.inject({}) do |h, v|
      value =
        case v.custom_field.field_format
        when 'date'
          row_date(row, "cf_#{v.custom_field.id}")
        else
          row_value(row, "cf_#{v.custom_field.id}")
        end
      if value
        h[v.custom_field.id.to_s] = v.custom_field.value_from_keyword(value, object)
      end
      h
    end

    object.send(:safe_attributes=, attributes, user)
    object
  end
end