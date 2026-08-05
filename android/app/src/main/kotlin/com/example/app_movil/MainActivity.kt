package com.example.app_movil

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Puente nativo con la app del reloj vía la Wear OS Data Layer API.
// Simétrico al MainActivity.kt de TandasWear: mismo nombre de canal y mismo
// formato de mensaje (ruta + datos como texto), para que ambos lados se
// entiendan sin necesitar un paquete de terceros.
class MainActivity : FlutterActivity(), MessageClient.OnMessageReceivedListener {
    private val channelName = "com.tandas.wear/mensajes"
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // En Android 12+ (API 31) BLUETOOTH_CONNECT es un permiso "dangerous":
        // declararlo en el manifest no basta, hay que pedirlo en tiempo de
        // ejecución o las llamadas a Wearable.* truenan con SecurityException.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                REQUEST_BLUETOOTH_CONNECT,
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enviarMensaje" -> {
                    val ruta = call.argument<String>("ruta") ?: ""
                    val datos = call.argument<String>("datos") ?: ""
                    enviarATodosLosNodos(ruta, datos)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        methodChannel = channel
    }

    override fun onResume() {
        super.onResume()
        Wearable.getMessageClient(this).addListener(this)
    }

    override fun onPause() {
        Wearable.getMessageClient(this).removeListener(this)
        super.onPause()
    }

    override fun onMessageReceived(event: MessageEvent) {
        val datos = String(event.data, Charsets.UTF_8)
        runOnUiThread {
            methodChannel?.invokeMethod(
                "mensajeRecibido",
                mapOf("ruta" to event.path, "datos" to datos),
            )
        }
    }

    private fun enviarATodosLosNodos(ruta: String, datos: String) {
        val messageClient = Wearable.getMessageClient(this)
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            for (node in nodes) {
                messageClient.sendMessage(node.id, ruta, datos.toByteArray(Charsets.UTF_8))
            }
        }
    }

    companion object {
        private const val REQUEST_BLUETOOTH_CONNECT = 1001
    }
}
