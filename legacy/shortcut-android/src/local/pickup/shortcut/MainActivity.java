package local.pickup.shortcut;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Toast;

/** Opens a fixed pickup page in the installed Pinduoduo app. */
public final class MainActivity extends Activity {
    private static final String TARGET_PACKAGE = "com.xunmeng.pinduoduo";
    private static final String PICKUP_URI =
            "pinduoduo://com.xunmeng.pinduoduo/mdkd/package";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            Intent pickupIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(PICKUP_URI));
            pickupIntent.setPackage(TARGET_PACKAGE);
            pickupIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(pickupIntent);
        } catch (ActivityNotFoundException exception) {
            Toast.makeText(this, R.string.app_not_found, Toast.LENGTH_LONG).show();
        } catch (SecurityException exception) {
            Toast.makeText(this, R.string.open_blocked, Toast.LENGTH_LONG).show();
        } finally {
            // Theme.NoDisplay activities must finish before reaching onResume.
            finish();
        }
    }
}
