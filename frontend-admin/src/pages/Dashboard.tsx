export function Dashboard() {
  return (
    <div>
      <h2 className="text-2xl font-bold mb-4">Admin Dashboard</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatCard label="Total Users" value="—" />
        <StatCard label="Active Teachers" value="—" />
        <StatCard label="Revenue (Month)" value="Rp —" />
      </div>
      <p className="mt-6 text-gray-600">
        Welcome to the OSEE Prep Hub admin. Connect to the API to see live stats.
      </p>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <div className="text-sm text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
    </div>
  );
}