const express = require('express');
const router = express.Router();
const streamController = require('../controllers/streamController');

router.get('/', (req, res, next) => streamController.streamUrl(req, res, next));

module.exports = router;

