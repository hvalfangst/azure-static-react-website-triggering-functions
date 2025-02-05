import React from 'react';
import { Buffer } from 'buffer';
import { AuthProvider } from './components/AuthProvider';
import CsvUploader from './components/CsvUploader';

window.Buffer = Buffer;

const App = () => {
    return (
        <AuthProvider>
            <CsvUploader />
        </AuthProvider>
    );
};

export default App;