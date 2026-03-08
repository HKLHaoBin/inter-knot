package cn.tiwat.interknot.webshell;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.webkit.WebViewAssetLoader;
import androidx.webkit.WebViewClientCompat;
import androidx.webkit.WebViewFeature;
import androidx.webkit.WebSettingsCompat;

import cn.tiwat.interknot.webshell.databinding.ActivityMainBinding;

public class MainActivity extends AppCompatActivity {
    private static final String APP_ASSET_HOST = "appassets.androidplatform.net";
    private static final String APP_URL = "https://" + APP_ASSET_HOST + "/assets/www/index.html";

    private ActivityMainBinding binding;
    private WebViewAssetLoader assetLoader;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        binding = ActivityMainBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        assetLoader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        WebView webView = binding.webView;
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);

        if (WebViewFeature.isFeatureSupported(WebViewFeature.FORCE_DARK)) {
            WebSettingsCompat.setForceDark(settings, WebSettingsCompat.FORCE_DARK_ON);
        }

        webView.setWebViewClient(new AppWebViewClient(assetLoader));
        webView.loadUrl(APP_URL);
    }

    @Override
    public void onBackPressed() {
        if (binding.webView.canGoBack()) {
            binding.webView.goBack();
            return;
        }
        super.onBackPressed();
    }

    private final class AppWebViewClient extends WebViewClientCompat {
        private final WebViewAssetLoader loader;

        private AppWebViewClient(WebViewAssetLoader loader) {
            this.loader = loader;
        }

        @Override
        public android.webkit.WebResourceResponse shouldInterceptRequest(
                @NonNull WebView view,
                @NonNull android.webkit.WebResourceRequest request
        ) {
            return loader.shouldInterceptRequest(request.getUrl());
        }

        @Override
        public boolean shouldOverrideUrlLoading(
                @NonNull WebView view,
                @NonNull android.webkit.WebResourceRequest request
        ) {
            Uri uri = request.getUrl();
            if (APP_ASSET_HOST.equals(uri.getHost())) {
                return false;
            }

            Intent browserIntent = new Intent(Intent.ACTION_VIEW, uri);
            startActivity(browserIntent);
            return true;
        }
    }
}
