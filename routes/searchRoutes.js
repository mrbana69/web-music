const express = require('express');
const router = express.Router();
const searchController = require('../controllers/searchController');

router.get('/', (req, res, next) => searchController.search(req, res, next));

module.exports = router;

