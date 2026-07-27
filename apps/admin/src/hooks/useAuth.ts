import { useState, useEffect } from 'react';
import axios from 'axios';

const API_BASE = '/api';

interface User {
  id: string;
  name: string;
  role: string;
  email: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  login: (credentials: { username: string; password: string }) => Promise<boolean>;
  logout: () => void;
}

export function useAuth(): AuthState {
  const [user, setUser] = useState<User | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem('adminToken');
    if (token) {
      setIsAuthenticated(true);
    }
  }, []);

  const login = async (credentials: { username: string; password: string }): Promise<boolean> => {
    try {
      const response = await axios.post(`${API_BASE}/auth/login`, credentials);
      const { token, user } = response.data;
      localStorage.setItem('adminToken', token);
      setUser(user);
      setIsAuthenticated(true);
      return true;
    } catch (error) {
      console.error('Login failed:', error);
      return false;
    }
  };

  const logout = () => {
    localStorage.removeItem('adminToken');
    setUser(null);
    setIsAuthenticated(false);
  };

  return { user, isAuthenticated, login, logout };
}