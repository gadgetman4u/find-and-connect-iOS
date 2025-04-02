// Example of fixing the route that shows HeardLogs
router.get('/heard-logs', async (req, res) => {
  try {
    // Option 1: Use the main Log collection (recommended)
    const logs = await Log.find({ logType: 'heardLog' }).sort({ uploadDate: -1 });
    
    // Option 2: If you must use the HeardLog collection, use proper joining
    /*
    const heardLogs = await HeardLog.find()
      .populate('logId')
      .sort({ 'logId.uploadDate': -1 });
    
    // Filter out any with null logId (could happen if references are broken)
    const logs = heardLogs.filter(hl => hl.logId).map(hl => hl.logId);
    */
    
    res.render('logs', { logs });
  } catch (error) {
    console.error('Error fetching heard logs:', error);
    res.status(500).send('Server Error');
  }
}); 