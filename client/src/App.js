import React, { useState, useEffect } from 'react';
import { PublicClientApplication } from '@azure/msal-browser';
import { Buffer } from 'buffer';

window.Buffer = Buffer;

// MSAL Configuration
const msalConfig = {
    auth: {
        clientId: process.env.REACT_APP_STATIC_WEB_APP_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AZURE_TENANT_ID}`,
        redirectUri: window.location.origin,
    },
};

const msalInstance = new PublicClientApplication(msalConfig);

const App = () => {
    const [file, setFile] = useState(null);
    const [error, setError] = useState('');
    const [modalVisible, setModalVisible] = useState(false);
    const [user, setUser] = useState(null);
    const [isInitialized, setIsInitialized] = useState(false);

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
                scopes: ['api://hvalfangst-function-app/Csv.Writer'],
                account
            });

            console.log('Token response:', tokenResponse);

            const token = tokenResponse.accessToken;

            const endpoint = 'https://hvalfangstlinuxfunctionapp.azurewebsites.net/api/upload_csv';

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

            console.log('Response:', response)

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
            setIsInitialized(true);
            const response = await msalInstance.loginPopup({
                scopes: ['openid'],
            });
            console.log('Sign in response:', response);
            console.log('User signed in successfully');
            setUser(response.account);
        } catch (error) {
            console.error('Error signing in:', error);
            setError(`Error signing in: ${error.message}`);
        }
    };

    const handleSignOut = async () => {
        if (!isInitialized) {
            console.error('MSAL instance is not initialized.');
            return;
        }
        await msalInstance.logoutPopup();
        setUser(null);
    };

    useEffect(() => {
        const initializeMsal = async () => {
            await msalInstance.initialize();
            setIsInitialized(true);
            const accounts = msalInstance.getAllAccounts();
            if (accounts.length > 0) {
                setUser(accounts[0]);
            }
        };

        initializeMsal();
    }, []);

    return (
        <div className="csv-uploader">
            <h1>CSV Uploader</h1>
            {user ? (
                <div>
                    <p>Welcome, {user.name}</p>
                    <button onClick={handleSignOut}>Sign Out</button>
                </div>
            ) : (
                <button onClick={handleSignIn}>Sign In</button>
            )}

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