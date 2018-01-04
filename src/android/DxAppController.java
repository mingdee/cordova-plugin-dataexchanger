package com.gttronics.ble.blelibrary.dataexchanger;

import android.bluetooth.BluetoothGattCharacteristic;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.gttronics.ble.blelibrary.BleController;
import com.gttronics.ble.blelibrary.BleControllerCallback;
import com.gttronics.ble.blelibrary.BleDevice;

import com.gttronics.ble.blelibrary.BleDeviceCallback;
import com.gttronics.ble.blelibrary.dataexchanger.callbacks.FirmwareMetaRetrievedCallback;
import com.gttronics.ble.blelibrary.dataexchanger.callbacks.FirmwareProgressCallback;
import com.gttronics.ble.blelibrary.dataexchanger.callbacks.FirmwareWriteCompletedCallback;
import com.gttronics.ble.blelibrary.dataexchanger.helpers.DxAppFirmLogStateMachine;
import com.gttronics.ble.blelibrary.dataexchanger.helpers.DxAppHelper;

/**
 * Created by EGUSI16 on 11/21/2016.
 */

public class DxAppController implements DataExchangerProfileCallback, BleDeviceCallback {

    public static class Config {
        private int devCount;
        private float pwrLevel;
        private double timeout;
        private boolean autoConnect;
        private boolean enableCmdChannel;
        private boolean enableChannelScram;
        private boolean enableTxCredit;

        public void setDevCount(int devCount) {
            this.devCount = devCount;
        }

        public void setPwrLevel(float pwrLevel) {
            this.pwrLevel = pwrLevel;
        }

        public void setTimeout(double timeout) {
            this.timeout = timeout;
        }

        public void setAutoConnect(boolean autoConnect) {
            this.autoConnect = autoConnect;
        }

        public void setEnableCmdChannel(boolean enableCmdChannel) {
            this.enableCmdChannel = enableCmdChannel;
        }

        public void setEnableChannelScram(boolean enableChannelScram) {
            this.enableChannelScram = enableChannelScram;
        }

        public void setEnableTxCredit(boolean enableTxCredit) {
            this.enableTxCredit = enableTxCredit;
        }
    }

    private static final String TAG = "DX_APP_CTLR";

    private static DxAppController dxAppController = null;

    private BleController bleController;
    private DataExchangerProfileCallback mDataReceiveCallback = null;
    private BleDeviceCallback mBleCallback = null;
    private BleControllerCallback mBleControllerCallback = null;
    private DxAppFirmLogStateMachine sm;

    private DxAppController(Context context, Config config) {
        bleController = BleController.getInstance(context);

        if (config != null) {

            for (int i = 0; i < config.devCount; i++) {
                if (config.pwrLevel == -127) {
//                    dxDev.setProximityConnecting(false);
                    continue;
                }

                DataExchangerDevice dxDev = new DataExchangerDevice(context, this);
                dxDev.setAutoConnect(config.autoConnect);
                dxDev.setTimeout(config.timeout);
                dxDev.setProximityConnecting(true);
                dxDev.setMinPowerLevel((int) (config.pwrLevel > -20? -2 : config.pwrLevel));

                DataExchangerProfile dxProfile = new DataExchangerProfile(dxDev, this);
                dxProfile.reset();
                dxProfile.enableRxNoti(true);
                dxProfile.enableRx2Noti(true);
                dxProfile.enableTxCreditNotification(true);
                dxProfile.enableTxCreditNoti(true);
                dxProfile.enableChannelScrambler(true);

                dxDev.registerProfile(dxProfile);
                bleController.registerDevice(dxDev);
            }
        }
    }

    public static DxAppController getInstance(Context context, Config config) {
        if (dxAppController == null)
            dxAppController = new DxAppController(context, config);

        return dxAppController;
    }

    public static DxAppController getInstance() {
        return dxAppController;
    }

    public void setProfileCallback(DataExchangerProfileCallback callback) { mDataReceiveCallback = callback; }

    public void setBleDeviceCallback(BleDeviceCallback callback) {
        mBleCallback = callback;
    }

    public boolean isBleSupport() {
        return bleController.isBleSupport();
    }

    public boolean isBluetoothEnabled() {
        return bleController.isBluetoothEnabled();
    }

    public void startScan() {
        bleController.startScan();
    }

    public void stopScan() { bleController.stopScan(); }

    public void disconnect() {
        bleController.disconnect();
    }

    public void clear() {
        if (bleController != null)
            bleController.clear();

        sm = null;
        bleController = null;
        dxAppController = null;
    }

    public boolean isConnected() {
        return bleController.isConnected();
    }

    public void connect(String UUID) {
        DataExchangerDevice dxDev = (DataExchangerDevice) bleController.connectDevice(UUID);
        sm = new DxAppFirmLogStateMachine(dxDev);
    }

    public boolean isBtOn() {
        return bleController.isBtOn();
    }

    public void setDelegate(BleControllerCallback callback)
    {
        bleController.setDelegate(callback);
    }

    public void enableTxCreditNoti(boolean enable) { }

    public void enableRxNoti(boolean enable) { }

    public void enableRx2Noti(boolean enable) { }

    public boolean sendData(byte[] data) {
        if (bleController.getConnectedDevice() == null)
            return false;

        return ((DataExchangerDevice) bleController.getConnectedDevice()).sendData(data);
    }

    public boolean sendCmd(byte[] data) {
        if (bleController.getConnectedDevice() == null)
            return false;

        return ((DataExchangerDevice) bleController.getConnectedDevice()).sendCmd(data, true);
    }

    public boolean enableCmd(boolean enabled) {
        if (bleController.getConnectedDevice() == null)
            return false;

        return ((DataExchangerDevice) bleController.getConnectedDevice()).enableCmd(enabled);
    }

    public String readTxCredit() {
        if (bleController.getConnectedDevice() == null)
            return "";

        return ((DataExchangerDevice) bleController.getConnectedDevice()).readTxCredit();
    }

    public boolean switchFirmwareImageToSlot(int slotId, boolean bKeepConfig) {
        String cmdStr = "AT+IMG=" + (bKeepConfig? slotId : slotId + 128) + "\r\n";
        return sendCmd(cmdStr.getBytes());
    }

    public boolean writeTxCreditReportLoopCount(int count) {
        DataExchangerDevice dxDev = (DataExchangerDevice) bleController.getConnectedDevice();
        return dxDev.writeTxCreditReportLoopCount(count);
    }

    // Retrieve meta data from data logger
    public boolean retrieveMetasFromDataLoggerWithCompletion() {

        DataExchangerDevice dxDev = (DataExchangerDevice) bleController.getConnectedDevice();
        DxAppFirmLogStateMachine sm = new DxAppFirmLogStateMachine(dxDev);
        //return sm.retrieveDataLoggerMetaWithCompletion();
        return true;
    }

    public boolean retrieveFirmwareMetaWithProgress(FirmwareProgressCallback progressCallback, FirmwareMetaRetrievedCallback metaRetrievedCallback) {
        return sm.retrieveFirmwareMetaWithProgress(progressCallback, metaRetrievedCallback);
    }

    public boolean writeFirmwareImageInSlot(byte slotIdx, byte[] firmData, byte[] scratchPad, FirmwareProgressCallback progressCallback, FirmwareWriteCompletedCallback completedCallback) {
        return sm.writeFirmwareImageInSlot(slotIdx, firmData, scratchPad, progressCallback, completedCallback);
    }

    public boolean deleteFirmwareImageFromSlot(byte slotIdx, FirmwareProgressCallback progressCallback, FirmwareWriteCompletedCallback completedCallback) {
        return sm.deleteFirmwareImageFromSlot(slotIdx, progressCallback, completedCallback);
    }

    public boolean primeFirmwareBinary(final byte[] firmBin, final String firmName, final FirmwareWriteCompletedCallback completedCallback, final FirmwareProgressCallback progressCallback) {
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
            @Override
            public void run() {
                Log.d(TAG, "Prime firmware");
                sm.primeFirmwareBinary(firmBin, firmName, completedCallback, progressCallback);
            }
        }, 3000);

        return true;
    }

    //Data Exchanger protocol
    @Override
    public void onRxDataAvailable(BleDevice dev, byte[] data) {
        mDataReceiveCallback.onRxDataAvailable(dev, data);
    }

    @Override
    public void onRx2DataAvailable(BleDevice dev, byte[] data) {
        Log.d(TAG, "onRx2DataAvailable" + new String(data));
        if (!sm.processRx2Data(data))
            mDataReceiveCallback.onRx2DataAvailable(dev, data);
    }

    @Override
    public void onTxCreditDataAvailable(BleDevice dev, byte[] data) {
        data = DxAppHelper.reverseArray(data);
        int credits = DxAppHelper.byteArrayToInt(data);
        sm.processTxCredit(credits);
        mDataReceiveCallback.onTxCreditDataAvailable(dev, data);
    }

    @Override
    public void onCharacteristicWrite(BluetoothGattCharacteristic c) {
        sm.onCharacteristicWrite(c);
        mDataReceiveCallback.onCharacteristicWrite(c);
    }

    @Override
    public void onDeviceStateChanged(BleDevice device, BLE_DEV_STATE state) {
        if (mBleCallback != null)
            mBleCallback.onDeviceStateChanged(device, state);
    }

    @Override
    public void onAllProfilesReady(BleDevice devive, boolean isAllReady) {
        if (mBleCallback != null)
            mBleCallback.onAllProfilesReady(devive, isAllReady);
    }

    @Override
    public void onUpdateValueForCharacteristic(BluetoothGattCharacteristic c) {
        if (mBleCallback != null)
            mBleCallback.onUpdateValueForCharacteristic(c);
    }

    @Override
    public void onCharacteristicDiscovered(BluetoothGattCharacteristic c) {
        Log.d(TAG, "onCharacteristicDiscovered");
    }
}
