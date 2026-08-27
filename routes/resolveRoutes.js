const express = require('express');
const router = express.Router();
const resolveController = require('../controllers/resolveController');

router.get('/', (req, res, next) => resolveController.resolve(req, res, next));

module.exports = router;

