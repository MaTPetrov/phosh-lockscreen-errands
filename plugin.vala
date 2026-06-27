/* plugin.vala */
using Gtk;
using Phosh;

public class PhoshLockscreenErrands : Phosh.Plugin {
    private ErrandsWidget? widget;

    public override void activate() {
        debug("Activating Errands lockscreen plugin");
        widget = new ErrandsWidget();
    }

    public override void deactivate() {
        debug("Deactivating Errands lockscreen plugin");
        widget = null;
    }

    public override Gtk.Widget? get_widget() {
        return widget;
    }
}

void phosh_plugin_init(Phosh.PluginManager manager) {
    manager.register_plugin(typeof(PhoshLockscreenErrands));
}
