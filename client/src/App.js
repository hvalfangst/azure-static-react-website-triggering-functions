import React, { useState } from 'react';
import { PublicClientApplication } from '@azure/msal-browser';
import { Buffer } from 'buffer';

window.Buffer = Buffer;

// MSAL Configuration
const msalConfig = {
    auth: {
        clientId: 'x',
        authority: 'https://login.microsoftonline.com/x',
        redirectUri: window.location.origin,
    },
};

const msalInstance = new PublicClientApplication(msalConfig);


const App = () => {
    const [file, setFile] = useState(null);
    const [error, setError] = useState('');
    const [modalVisible, setModalVisible] = useState(false);

    const handleFileChange = (e) => {
        setError('');
        setFile(e.target.files[0]);
    };

    const uploadFile = async (file) => {
        if (!file) {
            setError('Please select a file to upload');
            return;
        }

        try {
            console.log('Authenticating and uploading file...');

            // Acquire access token
            const account = msalInstance.getAllAccounts()[0];
            if (!account) {
                throw new Error('User is not signed in');
            }

            const tokenResponse = await msalInstance.acquireTokenSilent({
                scopes: ["api://61b4a548-3979-48df-b2df-37dc4e5e0e02/.default"],
                account
            });

            const token = tokenResponse.accessToken;

            const endpoint = 'x';

            // Read the file as a text string
            const fileContent = await file.text();

            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'text/csv', // Set content type to CSV
                    Authorization: `Bearer ${token}`, // Include OAuth token
                },
                body: fileContent, // Send the file content as the body
            });

            if (!response.ok) {
                const errorMessage = await response.text();
                throw new Error(`Failed to upload: ${errorMessage}`);
            }

            console.log('File uploaded successfully');
            setModalVisible(true); // Show success modal
        } catch (error) {
            console.error('Error uploading file:', error);
            setError(`Error uploading file: ${error.message}`);
        }
    };

    const handleFileUpload = () => {
        if (file) {
            uploadFile(file);
        } else {
            setError('Please select a file to upload');
        }
    };

    const closeModal = () => {
        setModalVisible(false);
    };

    const handleSignIn = async () => {
        try {
            await msalInstance.initialize();
            await msalInstance.loginPopup({
                scopes: ['x'],
            });
            console.log('User signed in successfully');
        } catch (error) {
            console.error('Error signing in:', error);
            setError(`Error signing in: ${error.message}`);
        }
    };

    const handleSignOut = () => {
        msalInstance.logoutPopup();
    };

    return (
        <div className="csv-uploader">
            <h1>CSV Uploader</h1>
            <button onClick={handleSignIn}>Sign In</button>
            <button onClick={handleSignOut}>Sign Out</button>

            <input type="file" accept=".csv" onChange={handleFileChange} />
            <button onClick={handleFileUpload}>Upload</button>
            {error && <p className="error">{error}</p>}

            {modalVisible && (
                <div className="modal">
                    <div className="modal-content">
                        <h2>Upload Successful!</h2>
                        <p>Your file has been uploaded to Azure Blob Storage via Azure Function.</p>
                        <button onClick={closeModal}>Close</button>
                    </div>
                </div>
            )}
        </div>
    );
};

export default App;
