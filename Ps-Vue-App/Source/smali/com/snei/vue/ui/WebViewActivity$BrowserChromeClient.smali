.class Lcom/snei/vue/ui/WebViewActivity$BrowserChromeClient;
.super Landroid/webkit/WebChromeClient;
.source "WebViewActivity.java"


# instance fields
.field final synthetic this$0:Lcom/snei/vue/ui/WebViewActivity;


# direct methods
.method constructor <init>(Lcom/snei/vue/ui/WebViewActivity;)V
    .registers 2

    iput-object p1, p0, Lcom/snei/vue/ui/WebViewActivity$BrowserChromeClient;->this$0:Lcom/snei/vue/ui/WebViewActivity;

    invoke-direct {p0}, Landroid/webkit/WebChromeClient;-><init>()V

    return-void
.end method


# virtual methods
.method public onConsoleMessage(Landroid/webkit/ConsoleMessage;)Z
    .registers 4

    sget-object v0, Ljava/lang/System;->out:Ljava/io/PrintStream;

    invoke-virtual {p1}, Landroid/webkit/ConsoleMessage;->message()Ljava/lang/String;

    move-result-object v1

    invoke-virtual {v0, v1}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V

    const/4 v0, 0x1

    return v0
.end method

.method public onJsAlert(Landroid/webkit/WebView;Ljava/lang/String;Ljava/lang/String;Landroid/webkit/JsResult;)Z
    .registers 5

    invoke-virtual {p4}, Landroid/webkit/JsResult;->confirm()V

    const/4 p0, 0x1

    return p0
.end method
