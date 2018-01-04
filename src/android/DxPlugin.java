package com.gttronics.ble.dataexchanger;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.support.v4.app.ActivityCompat;
import android.support.v4.content.ContextCompat;
import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;

import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.bluetooth.BluetoothGattCharacteristic;

import com.gttronics.ble.blelibrary.BleControllerCallback;
import com.gttronics.ble.blelibrary.BleDevice;
import com.gttronics.ble.blelibrary.BleDeviceCallback;
import com.gttronics.ble.blelibrary.dataexchanger.DataExchangerProfileCallback;

//import com.gttronics.ble.blelibrary.dataexchanger.DxAppController;
import com.gttronics.ble.DxAppController
import com.gttronics.ble.blelibrary.dataexchanger.callbacks.FirmwareMetaRetrievedCallback;
import com.gttronics.ble.blelibrary.dataexchanger.callbacks.FirmwareProgressCallback;
import com.gttronics.ble.blelibrary.dataexchanger.callbacks.FirmwareWriteCompletedCallback;

import java.nio.charset.Charset;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;
import java.util.UUID;

public class DxPlugin extends CordovaPlugin implements BleDeviceCallback, DataExchangerProfileCallback, BleControllerCallback{


	private static final String TAG = "DX_PLUG_IN";

    private static final int DISCONNECTED = 0;
    private static final int SCANNING = 2;
    private static final int CONNECTING = 3;
    private static final int CONNECTED = 1;

	private static final int MANUL_DISCONNECCT = 5;
    private static final int AUTO_RECONNECTING = 10;

    private static final int BLUETOOTH_ADMIN_PERMISSION = 1001;
    private static final int BLUETOOTH_PERMISSION = 1002;


	private String mDevUUID;

	private DxAppController dxAppController = null;
	CallbackContext mInitCallback;
	CallbackContext mRxDataCallback;
	CallbackContext mRx2DataCallback;
    CallbackContext mReadTxCreaditCallback;
	CallbackContext mScanCallback;
	CallbackContext mConnectCallback;
    CallbackContext mPrimeBinCallback;
    CallbackContext mDownloadFirmwareMetaCallback;
    CallbackContext mSwitchFirmwareToSlotCallback;

    DxAppController.Config mConfig;

	int mState = 0;
    private boolean isAlive = true;
    private boolean isAutoReconnecting = false;
    private boolean isDeviceReady = false;

    Timer reconnectTimer = null;

    public DxPlugin() {}

    @Override
	public boolean execute(final String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

		Log.d(TAG, "execute - " + action + ": " + args.toString());

		if (action.equals("init")) {
			init(args, callbackContext);
		}
        else if (action.equals("startScan")) {
            startScan(callbackContext);
        }
        else if (action.equals("startScanAndConnect")) {
            Log.e(TAG, "startScanAndConnect: called deprecated function");
        }
        else if (action.equals("stopScan")) {
            stopScan();
        }
		else if (action.equals("connect")) {
			connect(args.getString(0), callbackContext);
		}
        else if (action.equals("disconnect")) {
            disconnect();
        }
        else if (action.equals("sendData")) {
            sendData(args.getString(1));
        }
        else if (action.equals("sendCmd")) {
            sendCmd(args.getString(1));
        }
        else if (action.equals("readTxCredit")) {
            readTxCredit();
        }
        else if (action.equals("writeTxCreditReportLoopCount")) {}
        else if (action.equals("isConnected")) {}
        else if (action.equals("isEnabled")) {
            isEnabled(true);
        }
		else if (action.equals("enableRxDataNotification")) {
			enableRxDataNotification("", callbackContext);
		}
        else if (action.equals("disableRxDataNotification")) {}
        else if (action.equals("disableRxCmdNotification")) {}
        else if (action.equals("enableTxCreditNotification")) {}
        else if (action.equals("retrieveFirmwareMeta")) {
            retrieveFirmwareMeta(args.getString(0));
        }
        else if (action.equals("primeFirmwareBinary")) {
            String uuid = args.getString(0);
            String base64Bin = args.getString(1);
            byte[] firmBin = Base64.decode(base64Bin, Base64.DEFAULT);

            String firmName = args.getString(2);

            primeFirmwareBinary(uuid, firmBin, firmName, callbackContext);

        }
        else if (action.equals("switchFirmwareToSlot")) {
            String uuid = args.getString(0);
            int slotIdx = Integer.parseInt(args.getString(1));
            boolean keepConfig = args.getString(2).getBytes().equals("true");
            switchFirmwareToSlot(uuid, slotIdx, keepConfig, callbackContext);
        }
		else if (action.equals("enableRxCmdNotification")) {
			enableRxCmdNotification("", callbackContext);
		}
		else if (action.equals("isConnected")) {
			isConnected();
		}

		return true;
	}

    // App lifecycle
    @Override
    public void onStart() {
        super.onStart();
        isAlive = true;
        if (dxAppController == null && mConfig != null) {
            dxAppController = DxAppController.getInstance(cordova.getActivity().getApplicationContext(), mConfig);
        }
    }

    @Override
    public void onResume(boolean multitasking) {
        if (dxAppController == null) {
            Log.e(TAG, "onResume - Controller already cleared.");
            return;
        }

        if (dxAppController.isConnected()) {
            dxAppController.disconnect();
            sendSuccessResponse(mConnectCallback, getDisconnectResponse());
            return;
        }
        sendSuccessResponse(mConnectCallback, getDisconnectResponse());
//        startScan(null);
    }

    @Override
    public void onPause(boolean multitasking) {
        super.onPause(multitasking);
        if (dxAppController == null) {
            Log.e(TAG, "onPause - Controller is not initiated.");
            return;
        }

        dxAppController.stopScan();
        isAlive = false;
    }

    @Override
    public void onStop() {
        Log.d(TAG, "onStop");
        if (dxAppController != null) {
            dxAppController.clear();
            dxAppController = null;
        }
    }


    @Override
    public void onRequestPermissionResult(int requestCode, String permissions[], int[] grantResults) {
        Log.d(TAG, "onRequestPermissionsResult -" + requestCode);
        if (requestCode == BLUETOOTH_ADMIN_PERMISSION) {
            if (ContextCompat.checkSelfPermission(cordova.getActivity(), android.Manifest.permission.BLUETOOTH) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(cordova.getActivity(), new String[]{android.Manifest.permission.BLUETOOTH}, BLUETOOTH_PERMISSION);
                return;
            }

            allPermissionGranted();
        }
        else if (requestCode == BLUETOOTH_PERMISSION) {
            allPermissionGranted();
        }
    }

    // Plugin function
	public void init(JSONArray params, CallbackContext callback) throws JSONException {

		if (dxAppController != null) {
			Log.e(TAG, "already initialized.");
			callback.error("already initialized.");
			return;
		}

		mConfig = new DxAppController.Config();
		mConfig.setDevCount(params.length() > 0? Integer.parseInt(params.getString(0)) : 1);
		mConfig.setPwrLevel(params.length() > 1? Float.parseFloat(params.getString(1)) : -127);
		mConfig.setTimeout(params.length() > 2? Double.parseDouble(params.getString(2)) : 5.0);
		mConfig.setAutoConnect(params.length() > 3 && params.getString(3).toLowerCase().equals("true"));
		mConfig.setEnableCmdChannel(params.length() > 4 && params.getString(4).toLowerCase().equals("true"));
		mConfig.setEnableChannelScram(params.length() > 5 && params.getString(5).toLowerCase().equals("true"));
		mConfig.setEnableTxCredit(params.length() > 6 && params.getString(6).toLowerCase().equals("true"));

		Log.d(TAG, "initiating controller with config " + params.toString());
        mInitCallback = callback;

        // check bluetooth permission
        if (!cordova.hasPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)) {
            cordova.requestPermission(this, BLUETOOTH_ADMIN_PERMISSION, android.Manifest.permission.ACCESS_COARSE_LOCATION);
            return;
        }

        if (!cordova.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            cordova.requestPermission(this, BLUETOOTH_PERMISSION, android.Manifest.permission.ACCESS_FINE_LOCATION);
            return;
        }

        allPermissionGranted();
	}

    private void allPermissionGranted() {
        dxAppController = DxAppController.getInstance(cordova.getActivity().getApplicationContext(), mConfig);

        Log.d(TAG, "controller initiated successfully.");
//        mInitCallback.success(getInitSuccessResponse());
//        mInitCallback.error(getInitBleResponse());

        sendSuccessResponse(mInitCallback, getInitSuccessResponse());

        registerBluetoothReceiver();
    }
	
	public void startScan(CallbackContext callback) {
        if (callback != null)
            mScanCallback = callback;

        if (dxAppController == null) {
            Log.e(TAG, "dxController cleared");
            return;
        }

        if (!isAlive) {
            Log.e(TAG, "startScan - App is not active");
            sendFailResponse(mScanCallback, new JSONObject());
            return;
        }

        if (!dxAppController.isBtOn()) {
            reconnect(new TimerTask() {
                @Override
                public void run() {
                    sendSuccessResponse(mInitCallback, getInitBleResponse(false));
                    startScan(mScanCallback);
                }
            }, 3000);
            return;
        }

        clearReconnectTimer();
        sendSuccessResponse(mInitCallback, getInitBleResponse(true));

        mState = SCANNING;
		dxAppController.setProfileCallback(this);
        dxAppController.setBleDeviceCallback(this);
		dxAppController.setDelegate(this);
        dxAppController.startScan();
	}

    public void connect(String UUID, CallbackContext callback) {
        if (dxAppController == null) {
            Log.e(TAG, "connect - Controller not initiated");
            return;
        }

        mConnectCallback = callback;
        if (!isAlive) {
            Log.e(TAG, "connect - App is not active.");
            return;
        }

        if (mState == CONNECTING || mState == CONNECTED) {
            Log.e(TAG, "connect - App is already connected.");
            return;
        }

        mState = CONNECTING;
        Log.e(TAG, "connect - Connecting to device [" + UUID + "]");
        dxAppController.connect(UUID);
    }

    private void reconnect(TimerTask timerTask, int timeout) {
        if (reconnectTimer != null) {
            reconnectTimer.cancel();
            reconnectTimer = null;
        }

        Log.d(TAG, "start timer");
        reconnectTimer = new Timer();
        reconnectTimer.schedule(timerTask, timeout);
    }

    private void clearReconnectTimer() {
        Log.d(TAG, "clear timer");
        if (reconnectTimer != null) {
            reconnectTimer.cancel();
            reconnectTimer = null;
        }
    }

	@Deprecated
	public void startScanAndConnect(CallbackContext callback) {
		startScan(callback);
	}

	public void stopScan() {
		if (dxAppController == null){
			Log.e(TAG, "stopScan - Controller is not initiated");
			return;
		}

		dxAppController.stopScan();
	}

    public void disconnect() {
        if (dxAppController == null) {
            Log.e(TAG, "disconnect - Controller is not initiated");
            return;
        }

        clearReconnectTimer();
        dxAppController.stopScan();
        mState = MANUL_DISCONNECCT;

        if (!dxAppController.isConnected()) {
            Log.e(TAG, "disconnect - Already disconnected");
            return;
        }

        Log.d(TAG, "disconnect - Disconnect from device.");
        dxAppController.disconnect();
    }

	public boolean sendData(String data) {

        if (dxAppController == null) {
            Log.e(TAG, "sendData - Controller is not initiated");
            return false;
        }

		if (!data.contains("\r\n"))
			data += "\r\n";
		data = parseFromInput(data);
		byte[] dataTobeSent = data.getBytes();
		boolean succeed = dxAppController.sendData(dataTobeSent);
		
		return succeed;
	}

	public boolean sendCmd(String cmdStr) {

        if (dxAppController == null) {
            Log.e(TAG, "sendCmd - Controller is not initiated");
            return false;
        }

		if (!cmdStr.contains("\r\n"))
			cmdStr += "\r\n";
		cmdStr = parseFromInput(cmdStr);
		byte[] dataTobeSent = cmdStr.getBytes();
		boolean succeed = dxAppController.sendCmd(dataTobeSent);
		
		return succeed;
	}
	
	public void isEnabled(boolean enabled) {}

	public void isConnected() {
		 dxAppController.isConnected();
	}

	public void readTxCredit() {
        if (dxAppController == null) {
            Log.e(TAG, "readTxCredit - Controller is not initiated");
            return;
        }

        Boolean succeed = !TextUtils.isEmpty(dxAppController.readTxCredit());

        if (succeed) {
            mReadTxCreaditCallback.success();
        }
        else {
            mReadTxCreaditCallback.error("readTxCredit failed");
        }
    }

	public void writeTxCreditReportLoopCount(String cmd) {}

	public void enableRxDataNotification(String cmd, CallbackContext callbackContext) {
		Log.d(TAG, "RxDataNotification callback set");
		mRxDataCallback = callbackContext;
	}

	public void disableRxDataNotification(String cmd) {}

	public void enableRxCmdNotification(String cmd, CallbackContext callbackContext) {
		Log.d(TAG, "RxCmdNotification callback set");
		mRx2DataCallback = callbackContext;

	}

    public void retrieveFirmwareMeta(String uuid) {
        if (dxAppController == null) {
            Log.e(TAG, "Controller already cleared");
            return;
        }

        dxAppController.retrieveFirmwareMetaWithProgress(
                new FirmwareProgressCallback() {
                     @Override
                     public void onProgress(int stage, double progress) {
                         JSONObject rspJson = new JSONObject();

                         try {
                             rspJson.put("stage", String.valueOf(stage));
                             rspJson.put("progress", String.valueOf(progress));
                             rspJson.put("isdone", "false");
                         }
                         catch (JSONException e) {
                             e.printStackTrace();
                         }

                         sendSuccessResponse(mDownloadFirmwareMetaCallback, rspJson);
                     }
                 },
                new FirmwareMetaRetrievedCallback() {
                    @Override
                    public void onMeteRetrieved(int status, Map<String, Object> meta, String msg) {

                        JSONObject rspJson = new JSONObject(meta);
                        JSONObject metaJson = new JSONObject();

                        try {
                            for (Map.Entry<String, Object> entry : meta.entrySet()) {
                                metaJson.put(entry.getKey(), String.valueOf(entry.getValue()));
                            }

                            rspJson.put("metas", metaJson);
                            rspJson.put("status", TextUtils.isEmpty(msg) ? "OK" : "FAILED");
                            rspJson.put("reason", TextUtils.isEmpty(msg) ? "" : msg);
                            rspJson.put("isdone", "true");
                        }
                        catch (JSONException e) {
                            e.printStackTrace();
                        }

                        sendSuccessResponse(mDownloadFirmwareMetaCallback, rspJson);
                    }
                });
    }

    public void primeFirmwareBinary(String uuid, byte[] firmBin, String firmName, CallbackContext callbackContext) {
        Log.d(TAG, "prime firmware binary [" + uuid + " - " + firmName + "]");

        if (dxAppController == null) {
            Log.e(TAG, "primeFirmwareBinary - Controller already cleared");
            return;
        }

        mPrimeBinCallback = callbackContext;

        dxAppController.primeFirmwareBinary(firmBin, firmName,
                new FirmwareWriteCompletedCallback() {
                    @Override
                    public void onWriteCompleted(int status, Map<String, Object> metas, String msg) {
                        Log.d(TAG, "prime complete callback");
                        JSONObject rspJson = new JSONObject();
                        JSONObject metaJson = new JSONObject();

                        try {
                            if (metas != null) {
                                metas.remove("SlotScratchPads");
                                metas.remove("SlotValidMask");

                                for (Map.Entry<String, Object> entry : metas.entrySet()) {
                                    metaJson.put(entry.getKey(), String.valueOf(entry.getValue()));
                                }
                            }

                            rspJson.put("metas", metaJson);
                            rspJson.put("status", TextUtils.isEmpty(msg) ? "OK" : "FAILED");
                            rspJson.put("reason", TextUtils.isEmpty(msg) ? "" : msg);
                            rspJson.put("isdone", "true");
                        }
                        catch(JSONException e) {
                            e.printStackTrace();
                        }

                        sendSuccessResponse(mPrimeBinCallback, rspJson);

                    }
                },
                new FirmwareProgressCallback() {
                    @Override
                    public void onProgress(int stage, double progress) {
                        Log.d(TAG, "prime progress callback");
                        JSONObject rspJson = new JSONObject();

                        try {
                            rspJson.put("stage", String.valueOf(stage));
                            rspJson.put("progress", String.valueOf(progress));
                        }
                        catch(JSONException e) {
                            e.printStackTrace();
                        }

                        sendSuccessResponse(mPrimeBinCallback, rspJson);
                    }
                });
    }

    public void switchFirmwareToSlot(String uuid, int slotIdx, boolean keepConfig, CallbackContext callback) {

        if (dxAppController == null) {
            Log.e(TAG, "switchFirmwareToSlot - Controller already cleared");
        }

        boolean succeed = dxAppController.switchFirmwareImageToSlot(slotIdx, keepConfig);

        if (succeed) {
            callback.success();
        }
        else {
            callback.error("switchFirmwareImageToSlot failed");
        }
    }

	// Data exchanger interface
	@Override
	public void onDeviceStateChanged(BleDevice device, BLE_DEV_STATE state) {
		Log.d(TAG, "TAG1 - onDeviceStateChanged - [" + device.getDeviceName() + "]" + state);

		// Device is discovered and connected but its service has not been discovered
		if( state == BLE_DEV_STATE.CONNECTED_NOT_SVC_RDY ) {
			Log.d(TAG, "Device Found.");

			// Stop discovery scan if a device is connected
			dxAppController.stopScan();
		}

		// Device is disconnected
		else if( state == BLE_DEV_STATE.DISCONNECTED ) {
//            sendSuccessResponse(mConnectCallback, getDisconnectResponse());
            isDeviceReady = false;
            if (mState != MANUL_DISCONNECCT) {
                // Disconnect from device, need to restart scanning

                if (dxAppController == null) {
                    Log.e(TAG, "onDeviceStateChanged - Controller already cleared");
                    return;
                }

                if (isAutoReconnecting) {
                    Log.e(TAG, "onDeviceStateChanged - Auto reconnect already started");
                    return;
                }

                if (dxAppController.isConnected()) {
                    dxAppController.disconnect();
                    return;
                }

                // auto reconnect
                Log.d(TAG, "onDeviceStateChanged - Reconnecting");
                isAutoReconnecting = true;
                startScan(null);

			}
		}
	}

	@Override
	public void onAllProfilesReady(BleDevice dev, boolean isAllReady) {
		if( isAllReady )
		{
			// App is ready to interact with the BLE device.
            Log.d(TAG, "TAG1 - All profiles are ready, device " + dev.getDeviceName() + " connected successfully.");
            mState = CONNECTED;
            isDeviceReady = true;
            stopScan();

            if (isAutoReconnecting) {
                new Handler().postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        isAutoReconnecting = false;
                        sendSuccessResponse(mConnectCallback, getConnectSuccessResponse());
                    }
                }, 3000);
                return;
            }
            isAutoReconnecting = false;
            sendSuccessResponse(mConnectCallback, getConnectSuccessResponse());
		}
		else
		{
            mState = DISCONNECTED;
            isDeviceReady = false;
            isAutoReconnecting = false;
			Log.d(TAG, "Not all profiles are ready.");
			dev.close();
		}
	}

	@Override
	public void onUpdateValueForCharacteristic(BluetoothGattCharacteristic c) {
		Log.d(TAG, "onUpdateValueForCharacteristic: " + new String(c.getValue()));
	}

	@Override
	public void onRxDataAvailable(BleDevice dev, byte[] data) {
		String rxString =  new String(data);
        Log.d(TAG, "receive rx - " + rxString);
		if (mRxDataCallback != null) {
			sendSuccessResponse(mRxDataCallback, getDataReceiveResponse(rxString));
		}
	}

	@Override
	public void onRx2DataAvailable(BleDevice dev, byte[] data) {
		String rx2String = new String(data, Charset.forName("UTF8"));
        Log.d(TAG, "receive rx cmd - " + rx2String);
		if (mRx2DataCallback != null) {
			sendSuccessResponse(mRx2DataCallback, getDataReceiveResponse(rx2String));
		}
	}

	@Override
	public void onTxCreditDataAvailable(BleDevice dev, byte[] data) {
	}

	@Override
	public void onCharacteristicWrite(BluetoothGattCharacteristic c) {
	}

    @Override
    public void onCharacteristicDiscovered(BluetoothGattCharacteristic c) {
        Log.d(TAG, "onCharacteristicDiscovered: " + c.getUuid().toString());
    }

	@Override
	public void onUnknownDeviceDiscovered(BluetoothDevice btDev, int rssi, byte[] scanRecord) {}

	@Override
	public void onDeviceDiscovered(BluetoothDevice btDev, int rssi, byte[] scanRecord) {
		mDevUUID = UUID.nameUUIDFromBytes(btDev.getAddress().getBytes()).toString();
        Log.d(TAG, "onDeviceDiscovered: " + mDevUUID);

        if (isAutoReconnecting && dxAppController != null) {
            dxAppController.connect(mDevUUID);
            return;
        }

        sendSuccessResponse(mScanCallback, getScanSuccessResponse(btDev.getName(), rssi, mDevUUID));
	}

    // helper functions
	private JSONObject getInitSuccessResponse() {
		JSONObject rspJson = new JSONObject();

		try {
			rspJson.put("state", "init");
		}
		catch (JSONException e) {
			e.printStackTrace();
		}

		return rspJson;
	}


    private JSONObject getInitBleResponse(boolean isOn) {
        JSONObject rspJson = new JSONObject();

        try {
            rspJson.put("state", isOn ? "syson" : "sysoff");
        }
        catch (JSONException e) {
            e.printStackTrace();
        }

        return rspJson;
    }

	private JSONObject getScanSuccessResponse(String deviceName, int rssi, String uuid) {
		JSONObject rspJson = new JSONObject();
		JSONObject infoJson = new JSONObject();
		try {
			infoJson.put("NAME", deviceName);
			infoJson.put("RSSI", String.valueOf(rssi));
            infoJson.put("UUID", uuid);
			rspJson.put("info", infoJson);
			rspJson.put("state", "active");

			return rspJson;
		}
		catch (Exception e) {
			e.printStackTrace();
		}

		return null;
	}

	private JSONObject getConnectSuccessResponse() {
		JSONObject rspJson = new JSONObject();
		JSONObject infoJson = new JSONObject();

		try {
			infoJson.put("UUID", mDevUUID);
			rspJson.put("info", infoJson);
			rspJson.put("state", "connected");
			return rspJson;
		}
		catch (Exception e) {
			e.printStackTrace();
		}

		return null;
	}

	private JSONObject getDisconnectResponse() {
		JSONObject rspJson = new JSONObject();
		JSONObject infoJson = new JSONObject();

		try {
			infoJson.put("UUID", "");
			rspJson.put("info", infoJson);
			rspJson.put("state", "disconnected");
		}
		catch (Exception e) {
			e.printStackTrace();
		}

		return rspJson;
	}

	private JSONObject getDataReceiveResponse(String data) {
		data = formatToOutput(data);
		JSONObject dataJson = new JSONObject();
		JSONObject innerDataJson = new JSONObject();
		try {
			innerDataJson.put("data", data);
			dataJson.put("data", innerDataJson);

			return dataJson;
		}
		catch(Exception e) {
			e.printStackTrace();
		}

		return null;
	}

	private void sendSuccessResponse(CallbackContext callbackContext, JSONObject response) {
        if (callbackContext == null) {
            Log.e(TAG, "Failed send success callback, NULL callback context");
            return;
        }
		PluginResult result = new PluginResult(PluginResult.Status.OK, response);
		result.setKeepCallback(true);
		callbackContext.sendPluginResult(result);
	}

    private void sendFailResponse(CallbackContext callbackContext, JSONObject response) {
        PluginResult result = new PluginResult(PluginResult.Status.ERROR, response);
        result.setKeepCallback(true);
        callbackContext.sendPluginResult(result);

    }

	private void sendSuccessResponse(CallbackContext callbackContext, String response) {
		PluginResult result = new PluginResult(PluginResult.Status.OK, response);
		result.setKeepCallback(true);
		callbackContext.sendPluginResult(result);
	}

	// decode from base 64
	private String parseFromInput(String input) {
		byte[] base64 = Base64.decode(input.getBytes(), Base64.DEFAULT);
		return new String(base64);
	}

	// encode to base 64
	private String formatToOutput(String output) {
		byte[] base64 = Base64.encode(output.getBytes(), Base64.NO_WRAP);
		return new String(base64);
	}

	BroadcastReceiver receiver;
	private void registerBluetoothReceiver() {

        if (receiver != null) {
            Log.e(TAG, "Receiver already registered");
            return;
        }

        receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (intent.getAction().equals(BluetoothAdapter.ACTION_STATE_CHANGED)) {
                    if (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1) == BluetoothAdapter.STATE_OFF) {
                        sendSuccessResponse(mConnectCallback, getDisconnectResponse());

                        sendSuccessResponse(mInitCallback, getInitBleResponse(false));
                    }
                    else if (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1) == BluetoothAdapter.STATE_ON) {
                        Log.d(TAG, "On bluetooth alive");
                        sendSuccessResponse(mInitCallback, getInitBleResponse(true));
                        clearReconnectTimer();
                        startScan(null);
                    }
                }
            }
        };

        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(BluetoothAdapter.ACTION_STATE_CHANGED);
        cordova.getActivity().registerReceiver(receiver, intentFilter);

    }

	private void makeToast(final String msg) {
//		cordova.getActivity().runOnUiThread(new Runnable() {
//			public void run() {
//				Toast.makeText(cordova.getActivity(), msg, Toast.LENGTH_SHORT).show();
//
//			}
//		});
	}

    private String bytesToHex(byte[] bytes) {
        final char[] hexArray = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
        char[] hexChars = new char[bytes.length * 2];
        int v;
        for ( int j = 0; j < bytes.length; j++ ) {
            v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        return new String(hexChars);
    }
}