/* errands-widget.vala */
using Gtk;

public class ErrandsWidget : Box {
    private ErrandsData data;
    private Label title_label;
    private Box tasks_box;
    private string data_file_path;

    public ErrandsWidget() {
        Object(orientation: Orientation.VERTICAL, spacing: 12);
        
        // Применяем основной класс для виджета
        get_style_context().add_class("errands-widget");
        
        margin_top = 12;
        margin_bottom = 12;
        margin_start = 16;
        margin_end = 16;

        // Загружаем CSS
        load_css();

        // Path to Errands data file
        data_file_path = Path.build_filename(
            Environment.get_user_data_dir(),
            "errands",
            "data.json"
        );

        // Title
        title_label = new Label("<b>Upcoming Tasks</b>");
        title_label.use_markup = true;
        title_label.halign = Align.START;
        title_label.get_style_context().add_class("title");
        add(title_label);

        // Tasks container
        tasks_box = new Box(Orientation.VERTICAL, 8);
        tasks_box.get_style_context().add_class("tasks-container");
        add(tasks_box);

        // Load data
        data = new ErrandsData();
        load_data();

        // Watch for file changes
        watch_data_file();
    }

    private void load_css() {
        var provider = new Gtk.CssProvider();
        
        // Пробуем загрузить CSS из нескольких мест
        string[] css_paths = {
            // Из пользовательской директории
            Path.build_filename(
                Environment.get_user_data_dir(),
                "phosh", "plugins", "errands", "errands.css"
            ),
            // Из системной директории
            "/usr/share/phosh/plugins/errands/errands.css",
            // Из локальной сборки (для разработки)
            Path.build_filename(
                Environment.get_current_dir(),
                "data", "errands.css"
            )
        };
        
        bool loaded = false;
        foreach (var path in css_paths) {
            if (FileUtils.test(path, FileTest.EXISTS)) {
                try {
                    provider.load_from_path(path);
                    Gtk.StyleContext.add_provider_for_display(
                        Gdk.Display.get_default(),
                        provider,
                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                    );
                    loaded = true;
                    debug("Loaded CSS from: %s", path);
                    break;
                } catch (Error e) {
                    warning("Failed to load CSS from %s: %s", path, e.message);
                }
            }
        }
        
        if (!loaded) {
            warning("Could not find errands.css file");
        }
    }

    private void load_data() {
        // Clear existing tasks
        foreach (var child in tasks_box.get_children()) {
            tasks_box.remove(child);
        }

        // Load from file
        if (FileUtils.test(data_file_path, FileTest.EXISTS)) {
            data.load_from_json(data_file_path);
            display_tasks();
        } else {
            // Show placeholder
            var placeholder = new Label("No tasks");
            placeholder.get_style_context().add_class("dim-label");
            tasks_box.add(placeholder);
        }
    }

    private void display_tasks() {
        var upcoming = data.get_upcoming_tasks(7);

        if (upcoming.size == 0) {
            var placeholder = new Label("No upcoming tasks");
            placeholder.get_style_context().add_class("dim-label");
            tasks_box.add(placeholder);
            return;
        }

        // Group by list
        Gee.HashMap<string, Gee.ArrayList<ErrandsTask>> by_list =
            new Gee.HashMap<string, Gee.ArrayList<ErrandsTask>>();

        foreach (var task in upcoming) {
            if (!by_list.has_key(task.list_uid)) {
                by_list[task.list_uid] = new Gee.ArrayList<ErrandsTask>();
            }
            by_list[task.list_uid].add(task);
        }

        // Display each list
        foreach (var entry in by_list.entries) {
            var list = data.lists[entry.key];
            if (list == null) continue;

            // List header
            var list_header = new Label("<b>%s</b>".printf(list.name));
            list_header.use_markup = true;
            list_header.halign = Align.START;
            list_header.get_style_context().add_class("list-header");

            if (list.color != "") {
                list_header.get_style_context().add_class("colored-label");
                // Устанавливаем цвет динамически
                var css = "* { color: %s; }".printf(list.color);
                var provider = new Gtk.CssProvider();
                try {
                    provider.load_from_data(css, -1);
                    list_header.get_style_context().add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                } catch (Error e) {
                    warning("Failed to apply list color: %s", e.message);
                }
            }

            tasks_box.add(list_header);

            // Tasks
            foreach (var task in entry.value) {
                var task_widget = create_task_widget(task);
                tasks_box.add(task_widget);
            }

            var separator = new Separator(Orientation.HORIZONTAL);
            separator.get_style_context().add_class("task-separator");
            tasks_box.add(separator);
        }
    }

    private Widget create_task_widget(ErrandsTask task) {
        var box = new Box(Orientation.VERTICAL, 4);
        box.get_style_context().add_class("task-item");

        // Main task row
        var row = new Box(Orientation.HORIZONTAL, 8);

        // Checkbox (visual only)
        var checkbox = new Label(task.completed ? "✓" : "○");
        checkbox.get_style_context().add_class(task.completed ? "completed" : "pending");
        row.add(checkbox);

        // Task text and date
        var text_box = new Box(Orientation.VERTICAL, 2);
        
        var text_label = new Label(task.text);
        text_label.halign = Align.START;
        text_label.ellipsize = Pango.EllipsizeMode.END;
        text_label.get_style_context().add_class("task-text");
        if (task.completed) {
            text_label.get_style_context().add_class("completed-text");
        }
        text_box.add(text_label);

        // Due date
        if (task.due_date != "") {
            var due_label = new Label(task.get_formatted_due_date());
            due_label.get_style_context().add_class("due-date");

            // Check if overdue
            var due_dt = task.get_due_datetime();
            if (due_dt != null) {
                var now = new DateTime.now_local();
                if (due_dt.compare(now) < 0) {
                    due_label.get_style_context().add_class("overdue");
                }
            }
            
            text_box.add(due_label);
        }

        // Notes (если есть)
        if (task.notes != "" && task.notes.strip() != "") {
            var notes_label = new Label(task.notes.strip());
            notes_label.get_style_context().add_class("task-notes");
            notes_label.ellipsize = Pango.EllipsizeMode.END;
            notes_label.max_width_chars = 40;
            text_box.add(notes_label);
        }

        row.add(text_box);
        row.hexpand = true;

        // Priority indicator
        if (task.priority > 0) {
            var priority = new Label("!");
            priority.get_style_context().add_class("priority");
            row.add(priority);
        }

        box.add(row);

        // Subtasks
        if (task.subtasks.size > 0) {
            var subtasks_box = new Box(Orientation.VERTICAL, 4);
            subtasks_box.get_style_context().add_class("subtasks-container");

            foreach (var subtask in task.subtasks) {
                if (subtask.completed) continue;
                
                var subtask_row = new Box(Orientation.HORIZONTAL, 6);
                subtask_row.get_style_context().add_class("subtask-item");

                var sub_checkbox = new Label("○");
                sub_checkbox.get_style_context().add_class("pending");
                subtask_row.add(sub_checkbox);

                var sub_label = new Label(subtask.text);
                sub_label.get_style_context().add_class("subtask-text");
                sub_label.halign = Align.START;
                sub_label.ellipsize = Pango.EllipsizeMode.END;
                subtask_row.add(sub_label);
                
                subtasks_box.add(subtask_row);
            }
            
            box.add(subtasks_box);
        }

        return box;
    }

    private void watch_data_file() {
        // Watch for file changes and reload
        Timeout.add_seconds(30, () => {
            load_data();
            return Source.CONTINUE;
        });
    }
}
