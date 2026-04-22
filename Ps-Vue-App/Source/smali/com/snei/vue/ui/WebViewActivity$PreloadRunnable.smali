.class Lcom/snei/vue/ui/WebViewActivity$PreloadRunnable;
.super Ljava/lang/Object;
.source "WebViewActivity.java"

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field final synthetic this$0:Lcom/snei/vue/ui/WebViewActivity;


# direct methods
.method constructor <init>(Lcom/snei/vue/ui/WebViewActivity;)V
    .registers 2

    iput-object p1, p0, Lcom/snei/vue/ui/WebViewActivity$PreloadRunnable;->this$0:Lcom/snei/vue/ui/WebViewActivity;

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method


# virtual methods
.method public run()V
    .registers 2

    iget-object v0, p0, Lcom/snei/vue/ui/WebViewActivity$PreloadRunnable;->this$0:Lcom/snei/vue/ui/WebViewActivity;

    invoke-static {v0}, Lcom/snei/vue/ui/WebViewActivity;->access$100(Lcom/snei/vue/ui/WebViewActivity;)V

    return-void
.end method
