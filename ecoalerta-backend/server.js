const express = require('express');
// 1. Importamos Mongoose para manejar MongoDB
const mongoose = require('mongoose');

const app = express();
app.use(express.json());

// 2. CADENA DE CONEXIÓN A MONGO DB COMPASS LOCAL
// Se conectará a tu máquina (localhost) y creará automáticamente la base de datos 'ecoalerta_db'
const MONGO_URI = 'mongodb://127.0.0.1:27017/ecoalerta_db';

mongoose.connect(MONGO_URI)
    .then(() => console.log('✅ Conectado con éxito a MongoDB Compass local.'))
    .catch(err => console.error('❌ Error crítico al conectar a MongoDB:', err));

// 3. DEFINICIÓN DEL MODELO DE DATOS MEJORADO (Esquema de la Queja)
const ReportSchema = new mongoose.Schema({
    description: { type: String, required: true, minlength: 15 },
    priority: {
        level: { type: String, enum: ['green', 'yellow', 'red'], required: true },
        score: { type: Number, required: true }
    },
    // Formato GeoJSON estricto para consultas espaciales en Power BI o Python
    location: {
        type: { type: String, enum: ['Point'], default: 'Point', required: true },
        coordinates: { type: [Number], required: true } // [longitud, latitud]
    },
    address_optional: { type: String, default: "" },
    photo_url: { type: String, default: "" },
    user_data: {
        name: { type: String, default: "" },
        phone: { type: String, default: "" },
        email: { type: String, default: "" }
    },
    status: { 
        type: String, 
        enum: ['pending', 'analyzing', 'forwarded', 'resolved'], 
        default: 'pending' 
    },
    risk_score_ai: { type: Number, default: 0.0 },
    security_meta: {
        ip_address: { type: String, required: true },
        device_info: { type: String, required: true }
    }
}, { timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' } });

// Creamos el índice geoespacial para poder buscar reportes cercanos en el futuro
ReportSchema.index({ location: "2dsphere" });

// Registramos el modelo en Mongoose para interactuar con la colección 'reports'
const Report = mongoose.model('Report', ReportSchema);


// ==========================================
// 4. MOTOR DE RIESGO DE ECOALERTA (Risk Engine 2.0 - NLP Básico)
// ==========================================
function calcularPuntajeRiesgo(description, userPriorityLevel) {
    let score = 2.0; // Score Base Inicial

    // Diccionario de palabras clave críticas ambientales
    const palabrasCriticas = ['derrame', 'químico', 'incendio', 'fuego', 'explosión', 'veneno', 'tóxico', 'inminente', 'aceite', 'gasolina'];
    const palabrasModeradas = ['basura', 'olor', 'ruido', 'escombros', 'agua', 'fuga', 'alcantarilla'];

    const tokens = description.toLowerCase().split(/[ ,.+]+/);
    
    // Análisis léxico automatizado
    tokens.forEach(token => {
        if (palabrasCriticas.includes(token)) score += 2.5;
        if (palabrasModeradas.includes(token)) score += 0.5;
    });

    // Ponderación cruzada según lo seleccionado por el usuario
    if (userPriorityLevel === 'red') score += 3.0;
    if (userPriorityLevel === 'yellow') score += 1.5;

    // Retorna el score limitado a un techo analítico de 10.0
    return Math.min(score, 10.0);
}

// ==========================================
// 5. ENDPOINT POST: RECIBIR Y REGISTRAR QUEJA SEGURA
// ==========================================
app.post('/api/reports', async (req, res) => {
    try {
        // DETECCIÓN DE IP AUTOMÁTICA EN BACKEND
        // 'x-forwarded-for' se usa si la app pasa por proxies; si no, toma la IP directa del socket.
        const clientIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
        const userAgent = req.headers['user-agent'] || "Dispositivo Desconocido";

        const { description, priority, location, address_optional, photo_url, user_data } = req.body;

        // Validación obligatoria en servidor: Mínimo 15 caracteres
        if (!description || description.trim().length < 15) {
            return res.status(400).json({ 
                error: "La descripción del problema es obligatoria y debe contener mínimo 15 caracteres." 
            });
        }

        // Ejecutar el motor de IA integrado para determinar el nivel real de peligro
        const finalRiskScore = calcularPuntajeRiesgo(description, priority.level);

        // Construcción del documento estructurado para MongoDB
        const nuevaQueja = new Report({
            description,
            priority,
            location,
            address_optional,
            photo_url,
            user_data,
            risk_score_ai: finalRiskScore,
            security_meta: {
                ip_address: clientIP,
                device_info: userAgent
            }
        });

        // Guardar de forma atómica en tu base de datos local
        await nuevaQueja.save();

        // Respuesta limpia hacia el frontend de la App móvil
        res.status(201).json({
            success: true,
            message: "Queja registrada exitosamente en la central de datos.",
            case_id: nuevaQueja._id,
            risk_score_assigned: finalRiskScore
        });

    } catch (error) {
        console.error("❌ Error al procesar el reporte:", error);
        res.status(500).json({ error: "Error interno en el servidor al intentar registrar la queja." });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor de EcoAlerta encendido en el puerto ${PORT}`);
});