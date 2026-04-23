
.class Lcom/snei/vue/ui/WebViewActivity$BrowserClient;
.super Landroid/webkit/WebViewClient;
.source "WebViewActivity.java"


# instance fields
.field final synthetic this$0:Lcom/snei/vue/ui/WebViewActivity;


# direct methods
.method constructor <init>(Lcom/snei/vue/ui/WebViewActivity;)V
    .registers 2

    iput-object p1, p0, Lcom/snei/vue/ui/WebViewActivity$BrowserClient;->this$0:Lcom/snei/vue/ui/WebViewActivity;

    invoke-direct {p0}, Landroid/webkit/WebViewClient;-><init>()V

    return-void
.end method


# virtual methods
.method public shouldOverrideUrlLoading(Landroid/webkit/WebView;Ljava/lang/String;)Z
    .registers 4

    invoke-virtual {p1, p2}, Landroid/webkit/WebView;->loadUrl(Ljava/lang/String;)V

    const/4 v0, 0x1

    return v0
.end method
