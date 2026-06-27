/* errands-data.vala */
using Json;

public class ErrandsTask : Object {
    public string uid { get; set; }
    public string text { get; set; }
    public string notes { get; set; }
    public string due_date { get; set; }
    public bool completed { get; set; }
    public string parent { get; set; }
    public int priority { get; set; }
    public string color { get; set; }
    public string list_uid { get; set; }
    public Gee.ArrayList<ErrandsTask> subtasks { get; set; }

    public ErrandsTask() {
        subtasks = new Gee.ArrayList<ErrandsTask>();
    }

    public DateTime? get_due_datetime() {
        if (due_date == "") return null;
        try {
            // Format: 20260628T170000
            var date_str = due_date.substring(0, 8);
            var time_str = due_date.length > 9 ? due_date.substring(9, 6) : "000000";
            
            int year = int.parse(date_str.substring(0, 4));
            int month = int.parse(date_str.substring(4, 2));
            int day = int.parse(date_str.substring(6, 2));
            
            int hour = 0, minute = 0, second = 0;
            if (time_str.length >= 6) {
                hour = int.parse(time_str.substring(0, 2));
                minute = int.parse(time_str.substring(2, 2));
                second = int.parse(time_str.substring(4, 2));
            }
            
            return new DateTime.local(year, month, day, hour, minute, second);
        } catch (Error e) {
            warning("Failed to parse due date: %s", e.message);
            return null;
        }
    }

    public string get_formatted_due_date() {
        var dt = get_due_datetime();
        if (dt == null) return "";

        var now = new DateTime.now_local();
        var diff = dt.difference(now) / TimeSpan.DAY;

        if (diff == 0) {
            // Today
            return dt.format("%H:%M");
        } else if (diff == 1) {
            // Tomorrow
            return "Tomorrow, " + dt.format("%H:%M");
        } else if (diff < 7) {
            // This week
            return dt.format("%A, %H:%M");
        } else {
            return dt.format("%d %B %H:%M");
        }
    }
}

public class ErrandsList : Object {
    public string uid { get; set; }
    public string name { get; set; }
    public string color { get; set; }
    public bool deleted { get; set; }
    public bool show_completed { get; set; }
}

public class ErrandsData : Object {
    public Gee.HashMap<string, ErrandsList> lists { get; set; }
    public Gee.HashMap<string, ErrandsTask> tasks { get; set; }
    public Gee.ArrayList<ErrandsTask> root_tasks { get; set; }

    public ErrandsData() {
        lists = new Gee.HashMap<string, ErrandsList>();
        tasks = new Gee.HashMap<string, ErrandsTask>();
        root_tasks = new Gee.ArrayList<ErrandsTask>();
    }

    public void load_from_json(string json_path) {
        try {
            var file = File.new_for_path(json_path);
            string content;
            file.load_contents(null, out content);

            var parser = new Json.Parser();
            parser.load_from_data(content);
            var root = parser.get_root().get_object();

            // Load lists
            var lists_array = root.get_array_member("lists");
            lists_array.foreach_element((arr, index, node) => {
                var list_obj = node.get_object();
                var list = new ErrandsList();
                list.uid = list_obj.get_string_member("uid");
                list.name = list_obj.get_string_member("name");
                list.color = list_obj.get_string_member("color");
                list.deleted = list_obj.get_boolean_member("deleted");
                list.show_completed = list_obj.get_boolean_member("show_completed");
                
                if (!list.deleted) {
                    lists[list.uid] = list;
                }
            });

            // Load tasks
            var tasks_array = root.get_array_member("tasks");
            tasks_array.foreach_element((arr, index, node) => {
                var task_obj = node.get_object();
                var task = new ErrandsTask();
                
                task.uid = task_obj.get_string_member("uid");
                task.text = task_obj.get_string_member("text");
                task.notes = task_obj.get_string_member("notes");
                task.due_date = task_obj.get_string_member("due_date");
                task.completed = task_obj.get_boolean_member("completed");
                task.parent = task_obj.get_string_member("parent");
                task.priority = (int)task_obj.get_int_member("priority");
                task.color = task_obj.get_string_member("color");
                task.list_uid = task_obj.get_string_member("list_uid");

                tasks[task.uid] = task;
            });

            // Build hierarchy
            foreach (var task in tasks.values) {
                if (task.parent != "" && tasks.has_key(task.parent)) {
                    tasks[task.parent].subtasks.add(task);
                } else if (task.parent == "") {
                    root_tasks.add(task);
                }
            }

        } catch (Error e) {
            warning("Failed to load Errands data: %s", e.message);
        }
    }

    public Gee.ArrayList<ErrandsTask> get_upcoming_tasks(int days = 7) {
        var result = new Gee.ArrayList<ErrandsTask>();
        var now = new DateTime.now_local();
        var future = now.add_days(days);

        foreach (var task in tasks.values) {
            if (task.completed || task.deleted) continue;
            
            var due = task.get_due_datetime();
            if (due != null && due.compare(now) >= 0 && due.compare(future) <= 0) {
                result.add(task);
            }
        }

        // Sort by due date
        result.sort((a, b) => {
            var a_due = a.get_due_datetime();
            var b_due = b.get_due_datetime();
            
            if (a_due == null && b_due == null) return 0;
            if (a_due == null) return 1;
            if (b_due == null) return -1;
            
            return a_due.compare(b_due);
        });

        return result;
    }
}
