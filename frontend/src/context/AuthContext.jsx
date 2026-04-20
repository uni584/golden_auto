import React, { createContext, useContext, useState, useEffect } from "react";

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => {
    const raw = localStorage.getItem("ga_user");
    return raw ? JSON.parse(raw) : null;
  });

  useEffect(() => {
    if (user) localStorage.setItem("ga_user", JSON.stringify(user));
    else localStorage.removeItem("ga_user");
  }, [user]);

  const login = async (email, password) => {
    // MOCKED: any non-empty credentials succeed
    await new Promise((r) => setTimeout(r, 500));
    if (!email || !password) throw new Error("Ange e-post och lösenord");
    const name = email.split("@")[0];
    const u = {
      id: "u1",
      email,
      name: name.charAt(0).toUpperCase() + name.slice(1),
      role: email.includes("admin") ? "superadmin" : "admin",
    };
    setUser(u);
    return u;
  };

  const logout = () => setUser(null);

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
