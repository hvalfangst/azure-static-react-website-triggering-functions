import React, {useState} from 'react';
import {useAuth} from './AuthProvider';


const CsvUploader = () => {
    const {user, handleSignIn, handleSignOut, acquireToken} = useAuth();
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
            const tokenResponse = acquireToken(['api://hvalfangst-function-app/Csv.Writer']);
            const accessToken = tokenResponse.accessToken;
            const endpoint = 'https://hvalfangstlinuxfunctionapp.azurewebsites.net/api/upload_csv';
            const fileContent = await file.text();

            const response = await fetch(endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'text/csv',
                    Authorization: `Bearer ${accessToken}`,
                },
                body: fileContent,
            });

            if (!response.ok) {
                const errorMessage = await response.text();
                throw new Error(`Failed to upload: ${errorMessage}`);
            }

            setModalVisible(true);
        } catch (error) {
            console.error('Error uploading file:', error);
            setError(`Error uploading file: ${error.message}`);
        }
    };

    const handleFileUpload = async () => {
        if (file) {
            await uploadFile(file);
        } else {
            setError('Please select a file to upload');
        }
    };

    const closeModal = () => {
        setModalVisible(false);
    };

    return (
        <div className="csv-uploader">
            <div>
                <h1>CSV Uploader</h1>
                {user ? (
                    <div>
                        <p>Welcome, {user.name}</p>
                        <button onClick={handleSignOut}>Sign Out</button>
                    </div>
                ) : (
                    <button onClick={handleSignIn}>Sign In</button>
                )}
            </div>
            <div>
                <input type="file" accept=".csv" onChange={handleFileChange}/>
                <button onClick={handleFileUpload}>Upload</button>
                {error && <p className="error">{error}</p>}
            </div>
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

export default CsvUploader;