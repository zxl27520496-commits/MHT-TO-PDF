package com.example.mht_to_pdf

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.print.PrintAttributes
import android.print.PrintManager
import android.util.Log
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mht_to_pdf/converter"
    private var conversionWebView: WebView? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "convertMhtToPdf" -> {
                    val mhtPath = call.argument<String>("mhtPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (mhtPath != null && outputPath != null) {
                        convertMhtToPdf(mhtPath, outputPath, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing mhtPath or outputPath", null)
                    }
                }
                "getTempDirectory" -> {
                    result.success(cacheDir.absolutePath)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun convertMhtToPdf(mhtPath: String, outputPath: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another conversion is in progress", null)
            return
        }
        pendingResult = result

        Handler(Looper.getMainLooper()).post {
            val mhtFile = File(mhtPath)
            if (!mhtFile.exists()) {
                result.error("FILE_NOT_FOUND", "MHT file not found: $mhtPath", null)
                pendingResult = null
                return@post
            }

            val outputFile = File(outputPath)
            outputFile.parentFile?.mkdirs()

            val webView = WebView(this)
            conversionWebView = webView
            setupWebViewSettings(webView)

            var pageLoaded = false

            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    if (pageLoaded) return
                    pageLoaded = true
                    
                    view?.let { wv ->
                        Handler(Looper.getMainLooper()).postDelayed({
                            createPdf(wv, outputFile)
                        }, 1500)
                    }
                }

                override fun onReceivedError(
                    view: WebView?,
                    request: android.webkit.WebResourceRequest?,
                    error: android.webkit.WebResourceError?
                ) {
                    super.onReceivedError(view, request, error)
                    if (request?.isForMainFrame == true) {
                        val res = pendingResult
                        pendingResult = null
                        conversionWebView = null
                        webView.destroy()
                        res?.error("LOAD_ERROR", "Failed to load: ${error?.description}", null)
                    }
                }
            }

            webView.loadUrl("file://${mhtFile.absolutePath}")
        }
    }

    private fun setupWebViewSettings(webView: WebView) {
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.allowFileAccess = true
        settings.allowContentAccess = true
        settings.loadsImagesAutomatically = true
        settings.useWideViewPort = true
        settings.setSupportZoom(true)
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        settings.cacheMode = WebSettings.LOAD_NO_CACHE
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        settings.textZoom = 100
    }

    private fun createPdf(webView: WebView, outputFile: File) {
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT) {
                finishConversion(null, "Unsupported Android version", null)
                return
            }

            val printManager = getSystemService(Context.PRINT_SERVICE) as PrintManager
            val jobName = "MHT_PDF_${System.currentTimeMillis()}"

            val printAttributes = PrintAttributes.Builder()
                .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                .setResolution(PrintAttributes.Resolution("pdf", "pdf", 600, 600))
                .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                .setColorMode(PrintAttributes.COLOR_MODE_COLOR)
                .build()

            val adapter = webView.createPrintDocumentAdapter(jobName)
            val resultCallback = PdfWriteResultCallback(outputFile) { success, error ->
                finishConversion(if (success) outputFile.absolutePath else null, error, webView)
            }

            val fileDescriptor = android.os.ParcelFileDescriptor.open(
                outputFile,
                android.os.ParcelFileDescriptor.MODE_READ_WRITE or
                    android.os.ParcelFileDescriptor.MODE_CREATE or
                    android.os.ParcelFileDescriptor.MODE_TRUNCATE
            )

            val cancellationSignal = android.os.CancellationSignal()

            adapter.onStart()
            adapter.onLayout(
                printAttributes,
                printAttributes,
                null,
                object : android.print.PrintDocumentAdapter.LayoutResultCallback() {
                    override fun onLayoutFinished(info: android.print.PrintDocumentInfo?, changed: Boolean) {
                        adapter.onWrite(
                            arrayOf(android.print.PageRange.ALL_PAGES),
                            fileDescriptor,
                            cancellationSignal,
                            resultCallback
                        )
                    }

                    override fun onLayoutFailed(error: CharSequence?) {
                        adapter.onFinish()
                        try { fileDescriptor.close() } catch (_: Exception) {}
                        finishConversion(null, "Layout failed: ${error ?: "unknown"}", webView)
                    }
                },
                null
            )
        } catch (e: Exception) {
            finishConversion(null, "Exception: ${e.message}", webView)
        }
    }

    private fun finishConversion(outputPath: String?, error: String?, webView: WebView?) {
        val res = pendingResult
        pendingResult = null
        conversionWebView = null

        Handler(Looper.getMainLooper()).post {
            try {
                webView?.destroy()
            } catch (_: Exception) {}
        }

        if (outputPath != null) {
            res?.success(outputPath)
        } else {
            res?.error("CONVERSION_FAILED", error ?: "Unknown error", null)
        }
    }

    private class PdfWriteResultCallback(
        private val outputFile: File,
        private val onComplete: (Boolean, String?) -> Unit
    ) : android.print.PrintDocumentAdapter.WriteResultCallback() {
        override fun onWriteFinished(pages: Array<out android.print.PageRange>?) {
            onComplete(true, null)
        }

        override fun onWriteFailed(error: CharSequence?) {
            onComplete(false, error?.toString() ?: "Write failed")
        }

        override fun onWriteCancelled() {
            onComplete(false, "Cancelled")
        }
    }

    override fun onDestroy() {
        conversionWebView?.destroy()
        conversionWebView = null
        super.onDestroy()
    }
}
