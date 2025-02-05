import React, { createContext, useContext, useState } from 'react';
import { PublicClientApplication } from '@azure/msal-browser';

const AuthContext = createContext();

const msalConfig = {
    auth: {
        clientId: process.env.REACT_APP_STATIC_WEB_APP_CLIENT_ID,
        authority: `https://login.microsoftonline.com/${process.env.REACT_APP_AZURE_TENANT_ID}`,
        redirectUri: window.location.origin,
    },
};

const msalInstance = new PublicClientApplication(msalConfig);

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [isInitialized, setIsInitialized] = useState(false);

    const getCurrentAccount = () => {
        const accounts = msalInstance.getAllAccounts();
        return accounts.length > 0 ? accounts[0] : null;
    };

    const acquireToken = async (scopes) => {
        const account = getCurrentAccount();
        if (!account) {
            throw new Error('No account found');
        }
        return await msalInstance.acquireTokenSilent({
            scopes,
            account,
        });
    };

    const handleSignIn = async () => {
        try {
            await msalInstance.initialize();
            setIsInitialized(true);
            const response = await msalInstance.loginPopup({
                scopes: ['openid'],
            });
            setUser(response.account);
        } catch (error) {
            console.error('Error signing in:', error);
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

    return (
        <AuthContext.Provider value={{ user, handleSignIn, handleSignOut, acquireToken }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => useContext(AuthContext);