import "@/App.css";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "@/context/AuthContext";
import { Toaster } from "@/components/ui/sonner";

import PublicLayout from "@/pages/public/PublicLayout";
import Home from "@/pages/public/Home";
import ServicesPublic from "@/pages/public/ServicesPublic";
import Booking from "@/pages/public/Booking";
import Contact from "@/pages/public/Contact";

import AdminLogin from "@/pages/admin/AdminLogin";
import AdminLayout from "@/pages/admin/AdminLayout";
import Dashboard from "@/pages/admin/Dashboard";
import Bookings from "@/pages/admin/Bookings";
import Customers from "@/pages/admin/Customers";
import Vehicles from "@/pages/admin/Vehicles";
import WorkOrders from "@/pages/admin/WorkOrders";
import ServicesAdmin from "@/pages/admin/ServicesAdmin";
import StandardActions from "@/pages/admin/StandardActions";
import Receipts from "@/pages/admin/Receipts";
import Notifications from "@/pages/admin/Notifications";
import TireHotel from "@/pages/admin/TireHotel";
import SeasonReminders from "@/pages/admin/SeasonReminders";
import AuditLog from "@/pages/admin/AuditLog";
import Users from "@/pages/admin/Users";

const Protected = ({ children }) => {
  const { user } = useAuth();
  if (!user) return <Navigate to="/admin/login" replace />;
  return children;
};

function App() {
  return (
    <div className="App">
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<PublicLayout />}>
              <Route path="/" element={<Home />} />
              <Route path="/tjanster" element={<ServicesPublic />} />
              <Route path="/boka" element={<Booking />} />
              <Route path="/kontakt" element={<Contact />} />
            </Route>

            <Route path="/admin/login" element={<AdminLogin />} />
            <Route
              path="/admin"
              element={
                <Protected>
                  <AdminLayout />
                </Protected>
              }
            >
              <Route index element={<Dashboard />} />
              <Route path="bokningar" element={<Bookings />} />
              <Route path="kunder" element={<Customers />} />
              <Route path="fordon" element={<Vehicles />} />
              <Route path="arbetsorder" element={<WorkOrders />} />
              <Route path="tjanster" element={<ServicesAdmin />} />
              <Route path="standardatgarder" element={<StandardActions />} />
              <Route path="kvitton" element={<Receipts />} />
              <Route path="dackhotell" element={<TireHotel />} />
              <Route path="paminnelser" element={<SeasonReminders />} />
              <Route path="notiser" element={<Notifications />} />
              <Route path="auditlogg" element={<AuditLog />} />
              <Route path="anvandare" element={<Users />} />
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
          <Toaster richColors position="top-right" />
        </BrowserRouter>
      </AuthProvider>
    </div>
  );
}

export default App;
