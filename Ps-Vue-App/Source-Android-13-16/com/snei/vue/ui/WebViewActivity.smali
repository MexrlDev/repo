.class public Lcom/snei/vue/ui/WebViewActivity;
.super Landroid/app/Activity;
.source "WebViewActivity.java"


# instance fields
.field private handler:Landroid/os/Handler;

.field private preloadRunnable:Ljava/lang/Runnable;

.field private showWebViewRunnable:Ljava/lang/Runnable;

.field private splashContainer:Landroid/widget/FrameLayout;

.field private splashImage:Landroid/widget/ImageView;

.field private webView:Landroid/webkit/WebView;


# direct methods
.method public constructor <init>()V
    .registers 1

    invoke-direct {p0}, Landroid/app/Activity;-><init>()V

    return-void
.end method

.method static synthetic access$000(Lcom/snei/vue/ui/WebViewActivity;)V
    .registers 1

    invoke-direct {p0}, Lcom/snei/vue/ui/WebViewActivity;->showWebView()V

    return-void
.end method

.method static synthetic access$100(Lcom/snei/vue/ui/WebViewActivity;)V
    .registers 1

    invoke-direct {p0}, Lcom/snei/vue/ui/WebViewActivity;->preloadUrl()V

    return-void
.end method

.method private preloadUrl()V
    .registers 3
    .annotation build Landroid/annotation/SuppressLint;
        value = {
            "SetJavaScriptEnabled"
        }
    .end annotation

    :try_start_0
    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;

    if-eqz v0, :cond_c

   # URL to open.. Ofc that’s my GitHub I used
    const-string v1, "https://mexrldev.github.io/web-kit/default/main.html"

    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->loadUrl(Ljava/lang/String;)V
    :try_end_9
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_9} :catch_a

    goto :goto_c

    :catch_a
    move-exception v0

    :cond_b
    :goto_b
    return-void

    :cond_c
    :goto_c
    return-void
.end method

.method private showWebView()V
    .registers 2

    :try_start_0
    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;

    if-eqz v0, :cond_a

    invoke-virtual {p0, v0}, Lcom/snei/vue/ui/WebViewActivity;->setContentView(Landroid/view/View;)V

    const/4 v0, 0x0

    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->splashContainer:Landroid/widget/FrameLayout;
    :try_end_a
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_a} :catch_b

    :cond_a
    :goto_a
    return-void

    :catch_b
    move-exception v0

    goto :goto_a
.end method


# virtual methods
.method public onBackPressed()V
    .registers 2

    :try_start_0
    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;

    if-eqz v0, :cond_12

    invoke-virtual {v0}, Landroid/webkit/WebView;->canGoBack()Z

    move-result v0

    if-eqz v0, :cond_12

    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;

    invoke-virtual {v0}, Landroid/webkit/WebView;->goBack()V
    :try_end_f
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_f} :catch_10

    :goto_f
    return-void

    :catch_10
    move-exception v0

    goto :goto_15

    :cond_12
    :try_start_12
    invoke-super {p0}, Landroid/app/Activity;->onBackPressed()V
    :try_end_15
    .catch Ljava/lang/Exception; {:try_start_12 .. :try_end_15} :catch_10

    :goto_15
    goto :goto_f
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    .registers 12
    .param p1, "savedInstanceState"    # Landroid/os/Bundle;
    .annotation build Landroid/annotation/SuppressLint;
        value = {
            "SetJavaScriptEnabled"
        }
    .end annotation

    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    const/4 v6, 0x1

    :try_start_4
    invoke-static {v6}, Landroid/webkit/WebView;->setWebContentsDebuggingEnabled(Z)V
    :try_end_7
    .catch Ljava/lang/Exception; {:try_start_4 .. :try_end_7} :catch_0

    :catch_0
    new-instance v0, Landroid/widget/FrameLayout;

    invoke-direct {v0, p0}, Landroid/widget/FrameLayout;-><init>(Landroid/content/Context;)V

    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->splashContainer:Landroid/widget/FrameLayout;

    const/high16 v1, -0x10000000

    invoke-virtual {v0, v1}, Landroid/widget/FrameLayout;->setBackgroundColor(I)V

    new-instance v1, Landroid/widget/ImageView;

    invoke-direct {v1, p0}, Landroid/widget/ImageView;-><init>(Landroid/content/Context;)V

    iput-object v1, p0, Lcom/snei/vue/ui/WebViewActivity;->splashImage:Landroid/widget/ImageView;

    # UPDATED: new splash resource ID from provided info
    const v2, 0x7f0801d5

    invoke-virtual {v1, v2}, Landroid/widget/ImageView;->setImageResource(I)V

    sget-object v2, Landroid/widget/ImageView$ScaleType;->FIT_CENTER:Landroid/widget/ImageView$ScaleType;

    invoke-virtual {v1, v2}, Landroid/widget/ImageView;->setScaleType(Landroid/widget/ImageView$ScaleType;)V

    invoke-virtual {p0}, Lcom/snei/vue/ui/WebViewActivity;->getResources()Landroid/content/res/Resources;

    move-result-object v2

    invoke-virtual {v2}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v2

    iget v2, v2, Landroid/util/DisplayMetrics;->density:F

    const/high16 v3, 0x43960000    # 300.0f

    mul-float/2addr v3, v2

    float-to-int v3, v3

    new-instance v4, Landroid/widget/FrameLayout$LayoutParams;

    const/4 v5, -0x2

    invoke-direct {v4, v3, v5}, Landroid/widget/FrameLayout$LayoutParams;-><init>(II)V

    const/16 v3, 0x11

    iput v3, v4, Landroid/widget/FrameLayout$LayoutParams;->gravity:I

    invoke-virtual {v0, v1, v4}, Landroid/widget/FrameLayout;->addView(Landroid/view/View;Landroid/view/ViewGroup$LayoutParams;)V

    invoke-virtual {p0, v0}, Lcom/snei/vue/ui/WebViewActivity;->setContentView(Landroid/view/View;)V

    new-instance v0, Landroid/webkit/WebView;

    invoke-direct {v0, p0}, Landroid/webkit/WebView;-><init>(Landroid/content/Context;)V

    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;

    const/4 v1, 0x2

    const/4 v2, 0x0

    invoke-virtual {v0, v1, v2}, Landroid/webkit/WebView;->setLayerType(ILandroid/graphics/Paint;)V

    invoke-virtual {v0}, Landroid/webkit/WebView;->getSettings()Landroid/webkit/WebSettings;

    move-result-object v1

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setJavaScriptEnabled(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setDomStorageEnabled(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setDatabaseEnabled(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setAllowFileAccess(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setAllowContentAccess(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setLoadWithOverviewMode(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setUseWideViewPort(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setSupportZoom(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setBuiltInZoomControls(Z)V

    const/4 v3, 0x0

    invoke-virtual {v1, v3}, Landroid/webkit/WebSettings;->setDisplayZoomControls(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setGeolocationEnabled(Z)V

    invoke-virtual {v1, v6}, Landroid/webkit/WebSettings;->setJavaScriptCanOpenWindowsAutomatically(Z)V

    invoke-virtual {v1, v3}, Landroid/webkit/WebSettings;->setMediaPlaybackRequiresUserGesture(Z)V

    const/4 v3, 0x2

    invoke-virtual {v1, v3}, Landroid/webkit/WebSettings;->setCacheMode(I)V

    sget v3, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v4, 0x15

    if-lt v3, v4, :cond_8e
    const/4 v3, 0x2
    invoke-virtual {v1, v3}, Landroid/webkit/WebSettings;->setMixedContentMode(I)V
    :cond_8e

    # Android 10+ dark mode fix
    sget v3, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v4, 0x1d
    if-lt v3, v4, :cond_99
    const/4 v3, 0x0
    invoke-virtual {v1, v3}, Landroid/webkit/WebSettings;->setForceDark(I)V
    :cond_99

     # WEB info that makes website think you are using things like chrome so runs perfect.
    const-string v2, "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36"
    invoke-virtual {v1, v2}, Landroid/webkit/WebSettings;->setUserAgentString(Ljava/lang/String;)V

    # ---------- CookieManager with SDK guards ----------
    invoke-static {}, Landroid/webkit/CookieManager;->getInstance()Landroid/webkit/CookieManager;
    move-result-object v1

    # setAcceptThirdPartyCookies removed in API 31
    sget v2, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v3, 0x1f
    if-ge v2, v3, :cond_ae
    invoke-virtual {v1, v0, v6}, Landroid/webkit/CookieManager;->setAcceptThirdPartyCookies(Landroid/webkit/WebView;Z)V
    :cond_ae

    # setAcceptCookie
    invoke-virtual {v1, v6}, Landroid/webkit/CookieManager;->setAcceptCookie(Z)V

    # setAcceptFileSchemeCookies throws on API 30+
    sget v2, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v3, 0x1e
    if-ge v2, v3, :cond_bb
    invoke-static {v6}, Landroid/webkit/CookieManager;->setAcceptFileSchemeCookies(Z)V
    :cond_bb
    # ----------------------------------------------------------------

    new-instance v1, Lcom/snei/vue/ui/WebViewActivity$BrowserClient;
    invoke-direct {v1, p0}, Lcom/snei/vue/ui/WebViewActivity$BrowserClient;-><init>(Lcom/snei/vue/ui/WebViewActivity;)V
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->setWebViewClient(Landroid/webkit/WebViewClient;)V

    new-instance v1, Lcom/snei/vue/ui/WebViewActivity$BrowserChromeClient;
    invoke-direct {v1, p0}, Lcom/snei/vue/ui/WebViewActivity$BrowserChromeClient;-><init>(Lcom/snei/vue/ui/WebViewActivity;)V
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->setWebChromeClient(Landroid/webkit/WebChromeClient;)V

    # Handler setup with stored runnables
    new-instance v0, Landroid/os/Handler;
    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;
    move-result-object v1
    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V
    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->handler:Landroid/os/Handler;

    new-instance v1, Lcom/snei/vue/ui/WebViewActivity$PreloadRunnable;
    invoke-direct {v1, p0}, Lcom/snei/vue/ui/WebViewActivity$PreloadRunnable;-><init>(Lcom/snei/vue/ui/WebViewActivity;)V
    iput-object v1, p0, Lcom/snei/vue/ui/WebViewActivity;->preloadRunnable:Ljava/lang/Runnable;
    const-wide/16 v2, 0x3e8
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    new-instance v1, Lcom/snei/vue/ui/WebViewActivity$1;
    invoke-direct {v1, p0}, Lcom/snei/vue/ui/WebViewActivity$1;-><init>(Lcom/snei/vue/ui/WebViewActivity;)V
    iput-object v1, p0, Lcom/snei/vue/ui/WebViewActivity;->showWebViewRunnable:Ljava/lang/Runnable;
    const-wide/16 v2, 0x7d0
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    return-void
.end method

.method protected onDestroy()V
    .registers 3

    # Cancel pending Handler callbacks
    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->handler:Landroid/os/Handler;
    if-eqz v0, :cond_1b
    iget-object v1, p0, Lcom/snei/vue/ui/WebViewActivity;->preloadRunnable:Ljava/lang/Runnable;
    if-eqz v1, :cond_9
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    :cond_9
    iget-object v1, p0, Lcom/snei/vue/ui/WebViewActivity;->showWebViewRunnable:Ljava/lang/Runnable;
    if-eqz v1, :cond_e
    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V
    :cond_e
    const/4 v0, 0x0
    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->handler:Landroid/os/Handler;
    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->preloadRunnable:Ljava/lang/Runnable;
    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->showWebViewRunnable:Ljava/lang/Runnable;

    :cond_1b
    # Clean up WebView
    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;
    if-eqz v0, :cond_2b
    invoke-virtual {v0}, Landroid/webkit/WebView;->stopLoading()V
    invoke-virtual {v0}, Landroid/webkit/WebView;->clearHistory()V
    invoke-virtual {v0}, Landroid/webkit/WebView;->destroy()V
    const/4 v0, 0x0
    iput-object v0, p0, Lcom/snei/vue/ui/WebViewActivity;->webView:Landroid/webkit/WebView;
    :cond_2b

    invoke-super {p0}, Landroid/app/Activity;->onDestroy()V
    return-void
.end method
- [ ] 
