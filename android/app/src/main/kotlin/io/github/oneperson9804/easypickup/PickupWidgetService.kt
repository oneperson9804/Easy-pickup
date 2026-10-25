package io.github.oneperson9804.easypickup

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/** Supplies rows on demand without sending the entire parcel list in one widget update. */
class PickupWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext, intent.getIntExtra("width", 260))

    private class Factory(private val context: Context, private val width: Int) : RemoteViewsFactory {
        private var items = emptyList<WidgetParcel>()
        private var appearance = WidgetAppearance(true, true, .42)
        override fun onCreate() = Unit
        override fun onDataSetChanged() {
            ParcelStore(context).use { store ->
                appearance = WidgetAppearance.read(store)
                items = store.pending().second
            }
        }
        override fun onDestroy() { items = emptyList() }
        override fun getCount() = items.size
        override fun getViewAt(position: Int): RemoteViews? = items.getOrNull(position)?.let { appearance.row(context, it, width) }
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 1
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = false
    }
}
